# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe AgentWorker do
  it 'starts with no gems or injected Ruby and shell startup code' do
    Dir.mktmpdir do |directory|
      root = Pathname(directory)
      (root / 'bin').mkdir
      FileUtils.cp_r(File.expand_path('../../lib', __dir__), root / 'lib')
      injected = root / 'injected.rb'
      marker = root / 'startup-ran'
      injected.write("File.write(#{marker.to_s.dump}, 'unexpected')\n")
      bash_env = root / 'bash-env'
      bash_env.write("touch #{Shellwords.escape(marker.to_s)}\n")
      environment = {
        'RUBYOPT' => "-r#{injected}", 'RUBYLIB' => root.to_s, 'RUBYGEMS_GEMDEPS' => injected.to_s,
        'GEM_HOME' => root.to_s, 'GEM_PATH' => root.to_s, 'GEMRC' => injected.to_s,
        'BUNDLE_GEMFILE' => injected.to_s, 'BASH_ENV' => bash_env.to_s
      }
      %w[run_agent_task].each do |name|
        wrapper = root / 'bin' / name
        source = File.read(File.expand_path("../../bin/#{name}", __dir__))
        wrapper.write(source.sub('/opt/homebrew/opt/ruby@3.4/bin/ruby', RbConfig.ruby))
        wrapper.chmod(0o700)
        output, errors, status = Open3.capture3(environment, wrapper.to_s, '--help')
        expect(status.success?).to be(true), errors
        expect(output).to include('--task', '--output')
        expect(marker).not_to exist
      end
    end
  end
end
