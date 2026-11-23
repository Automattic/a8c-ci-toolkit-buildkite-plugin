#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'
require 'rspec'
require 'tmpdir'

# Runs the real `bin/annotate_test_failures` wrapper and Ruby script (the `.bats` file covers the wrapper with stubs),
# with a fake `buildkite-agent` recording the annotation calls.
context 'annotate_test_failures end to end' do
  let(:bin) { File.expand_path('../bin/annotate_test_failures', __dir__) }

  def run_in_tmpdir(junit_xml)
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'report.junit'), junit_xml)
      File.write(File.join(dir, 'buildkite-agent'), "#!/usr/bin/env bash\necho \"$@\" >> agent_calls.log\n")
      File.chmod(0o755, File.join(dir, 'buildkite-agent'))

      env = { 'PATH' => "#{dir}:#{ENV.fetch('PATH')}", 'SLACK_WEBHOOK' => nil, 'RBENV_VERSION' => nil }
      out, status = Open3.capture2e(env, bin, 'report.junit', chdir: dir)
      calls = File.exist?(File.join(dir, 'agent_calls.log')) ? File.read(File.join(dir, 'agent_calls.log')) : ''
      [out, status, calls]
    end
  end

  it 'annotates the build with the failed tests' do
    xml = <<~XML
      <testsuite><testcase classname="Suite" name="test_fails"><failure message="boom">details</failure></testcase></testsuite>
    XML
    out, status, calls = run_in_tmpdir(xml)

    expect(status).to be_success
    expect(out).to include('1 test(s) have failed')
    expect(calls).to include('annotate').and include('--style error')
  end

  it 'removes the previous annotations when all tests pass' do
    out, status, calls = run_in_tmpdir('<testsuite><testcase classname="Suite" name="test_passes"/></testsuite>')

    expect(status).to be_success
    expect(out).to include('No test have failed')
    expect(calls).to include('annotation remove')
  end
end
