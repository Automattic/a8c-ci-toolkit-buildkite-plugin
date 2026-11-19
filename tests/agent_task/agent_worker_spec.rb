# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe AgentWorker do
  let(:fixture) { Fixtures::Worker.new }

  after { fixture.close }

  it 'reports a reproduced failure and preserves local commits in an applicable patch', :aggregate_failures do
    fixture.write_agent(diagnostic: '', local_commit: true, failing_check: true, summary: 'Reproduced the issue.')
    expect(fixture.worker.run).to eq(0)
    expect(fixture.result).to include('status' => 'completed', 'summary' => 'Reproduced the issue.', 'validation' => include('status' => 'failed'))
    expect((fixture.output / 'evidence/reproduce.log').read).to include('Reproduced the issue')
    expect(fixture.output / 'evidence/verify.log').not_to exist
    patch = (fixture.output / 'changes.patch').binread
    expect(patch).to include('tracked.txt', 'added.txt', 'GIT binary patch')
    applied = fixture.root / 'applied'
    Fixtures.command('git', 'clone', '--quiet', fixture.repo.to_s, applied.to_s)
    Fixtures.command('git', 'apply', (fixture.output / 'changes.patch').to_s, cwd: applied)
    expect((applied / 'added.txt').binread).to eq("new\x00binary\n")
    expect((applied / 'tracked.txt').read).to eq("after\n")
    expect((fixture.output / 'evidence/agent-errors.log').read).to include('did not write any stderr diagnostics')
  end

  it 'uses the copied base adapter after the checkout verifier is edited' do
    fixture.mode = 'change'
    (fixture.adapter / 'verify.sh').write("exit 9\n")
    fixture.commit
    fixture.write_agent(edit_verifier: true)
    expect(fixture.worker.run).to eq(1)
    expect(fixture.result).to include('status' => 'failed', 'validation' => include('status' => 'failed'))
    expect(fixture.output / 'changes.patch').to be_file
  end

  it 'rejects malformed public descriptions' do
    [{}, { 'title' => 'Title', 'description' => 'Body', 'testing' => '' },
     { 'title' => "line\nbreak", 'description' => 'Body', 'testing' => 'Tests' }].each do |metadata|
      expect do
        described_class.validate_agent_result('status' => 'completed', 'summary' => 'Done', 'questions' => [],
                                              'validation' => { 'status' => 'not_run', 'summary' => 'Not run' }, 'pull_request' => metadata)
      end.to raise_error(AgentWorker::TaskError)
    end
  end

  it 'returns questions without verification and preserves a partial patch' do
    (fixture.adapter / 'verify.sh').write("exit 9\n")
    fixture.commit
    fixture.write_agent(status: 'needs_input')
    expect(fixture.worker.run).to eq(0)
    expect(fixture.result).to include('status' => 'needs_input', 'questions' => ['Which layout is expected?'], 'validation' => include('status' => 'not_run'))
    expect(fixture.output / 'evidence/verify.log').not_to exist
    expect(fixture.output / 'changes.patch').to be_file
  end

  it 'preserves an empty patch when questions need no edits' do
    fixture.write_agent(status: 'needs_input', make_changes: false)
    expect(fixture.worker.run).to eq(0)
    expect(fixture.result['status']).to eq('needs_input')
    expect((fixture.output / 'changes.patch').binread).to eq('')
  end

  it 'preserves partial changes when the model fails' do
    fixture.write_agent(exit_code: 1)
    expect(fixture.worker.run).to eq(1)
    expect(fixture.result['status']).to eq('failed')
    expect((fixture.output / 'changes.patch').binread).to include('added.txt')
  end

  it 'keeps investigation findings when the temporary patch exceeds its limit' do
    stub_const('AgentWorker::MAX_PATCH_BYTES', 64)
    fixture.write_agent(failing_check: true, summary: 'Reproduced the issue.'.ljust(8000, 'x'))
    expect(fixture.worker.run).to eq(0)
    expect(fixture.result).to include('status' => 'completed', 'validation' => include('status' => 'failed'))
    expect(fixture.result['summary']).to start_with('Reproduced the issue.')
    expect(fixture.result['summary']).to end_with('The temporary patch could not be saved.')
    expect(fixture.result['summary'].length).to be <= 8000
    expect(fixture.output / 'changes.patch').not_to exist
  end

  it 'fails a change request when its patch cannot be saved' do
    stub_const('AgentWorker::MAX_PATCH_BYTES', 64)
    fixture.mode = 'change'
    fixture.write_agent
    expect(fixture.worker.run).to eq(1)
    expect(fixture.result).to include('status' => 'failed', 'validation' => include('status' => 'passed'))
    expect(fixture.output / 'changes.patch').not_to exist
  end

  it 'bounds and redacts stderr without exposing the raw model response', :aggregate_failures do
    secret = 'test-dedicated-key'
    final_error = "\nFinal error: #{secret}"
    diagnostic = "Old diagnostic\n#{secret}#{'x' * (16_384 - (secret.length / 2) - final_error.length)}#{final_error}"
    fixture.write_agent(exit_code: 1, diagnostic: diagnostic)
    expect(fixture.worker.run).to eq(1)
    log = (fixture.output / 'evidence/agent-errors.log').binread
    expect(log.bytesize).to be <= 16_384
    expect(log).to include("Final error: #{'*' * secret.length}")
    expect(log).not_to include(secret, 'dedicated-key')
    expect(fixture.output / 'evidence/model-response.json').not_to exist
    expect(fixture.result['status']).to eq('failed')
    expect((fixture.output / 'changes.patch').binread).to include('added.txt')
  end

  it 'keeps repeated key redaction from pulling a partial key into the tail' do
    secret = 'test-dedicated-key'
    diagnostic = fixture.root / 'stderr.log'
    diagnostic.binwrite(secret + ('x' * (16_384 - (2 * secret.length) + (secret.length / 2))) + (secret * 2))
    (fixture.output / 'evidence').mkpath
    fixture.worker.save_agent_errors(diagnostic)
    log = (fixture.output / 'evidence/agent-errors.log').binread
    expect(log.bytesize).to eq(16_384)
    expect(log).to start_with('x' * 100)
    expect(log).to end_with('*' * (2 * secret.length))
    expect(log).not_to include('key')
  end

  it 'investigates without requiring a final verification script' do
    (fixture.adapter / 'verify.sh').unlink
    fixture.commit
    expect(fixture.worker.run).to eq(0)
    expect(fixture.result['status']).to eq('completed')
  end

  it 'requires a trusted GitHub repository name' do
    ['', '../repo', 'https://github.com/example/app', 'example/app?query', 'example/app/extra'].each do |repository|
      expect { described_class.validate_task(fixture.task, repository: repository) }.to raise_error(AgentWorker::TaskError)
    end
  end

  it 'fails before the model if the adapter is missing' do
    (fixture.adapter / 'prepare.sh').unlink
    fixture.commit
    expect(fixture.worker.run).to eq(1)
    expect(fixture.result).to include('summary' => include('required app adapter'), 'validation' => include('status' => 'not_run'))
  end

  it 'stops before the model when preparation fails' do
    (fixture.adapter / 'prepare.sh').write("exit 9\n")
    fixture.commit
    expect(fixture.worker.run).to eq(1)
    expect(fixture.result['summary']).to include('preparation failed')
    expect((fixture.output / 'changes.patch').binread).to eq('')
  end

  it 'does not overwrite existing output' do
    fixture.output.mkdir
    existing = fixture.output / 'result.json'
    existing.write('prior result')
    expect { fixture.worker.run }.to raise_error(AgentWorker::TaskError)
    expect(existing.read).to eq('prior result')
  end

  it 'does not follow output or log symlinks' do
    target = fixture.root / 'target'
    target.mkdir
    fixture.output.make_symlink(target)
    expect { fixture.worker.run }.to raise_error(AgentWorker::TaskError)
    log = fixture.root / 'log'
    log.make_symlink(target / 'new-file')
    expect { described_class.open_output(log) }.to raise_error(Errno::ELOOP)
    expect(target / 'new-file').not_to exist
  end

  it 'does not inherit host credentials or Ruby startup configuration' do
    values = { 'BUILDKITE_AGENT_ACCESS_TOKEN' => 'private', 'GH_TOKEN' => 'private', 'AWS_ACCESS_KEY_ID' => 'private',
               'SSH_AUTH_SOCK' => 'private', 'RUBYOPT' => '-rdoes-not-exist', 'RUBYLIB' => '/untrusted' }
    original = ENV.to_h
    begin
      ENV.update(values)
      expect(fixture.worker.run).to eq(0)
      expect(described_class.clean_environment(fixture.root, fixture.root, fixture.output)).not_to have_key('ANTHROPIC_API_KEY')
    ensure
      ENV.replace(original)
    end
  end

  it 'uses the task user’s Ruby shims for noninteractive repository commands' do
    home = fixture.root / 'home'
    shims = home / '.rbenv/shims'
    shims.mkpath
    (fixture.repo / '.ruby-version').write("3.4.9\n")
    %w[ruby bundle].each do |name|
      shim = shims / name
      shim.write(<<~SH)
        #!/bin/bash
        set -eu
        test "$RBENV_ROOT" = "$HOME/.rbenv"
        printf '%s %s %s\\n' '#{name}' "$(cat .ruby-version)" "$*"
      SH
      shim.chmod(0o700)
    end
    log = fixture.root / 'ruby.log'
    environment = described_class.clean_environment(home, fixture.root, fixture.output)
    runner = AgentWorker::Runner.new(AgentWorker.monotonic + 5)
    status = runner.run(['/bin/bash', '-c', 'ruby --version && bundle exec fastlane --version'], fixture.repo, environment, log)
    expect(status).to eq(0)
    expect(log.read.lines(chomp: true)).to eq(['ruby 3.4.9 --version', 'bundle 3.4.9 exec fastlane --version'])
  end

  it 'rejects arbitrary repositories, branches, commands and malformed fields' do
    { 'repository' => 'other/repo', 'commit' => 'trunk', 'command' => 'touch surprise', 'task_id' => '../escape',
      'mode' => 'unknown', 'version' => true, 'timeout_seconds' => true, 'prompt' => '', 'context' => 'x' * 16_001 }.each do |field, value|
      expect { described_class.validate_task(fixture.task.merge(field => value), repository: Fixtures::REPOSITORY) }.to raise_error(AgentWorker::TaskError)
    end
  end

  it 'applies the task byte limit to multibyte context' do
    expect { described_class.validate_task(fixture.task.merge('context' => '😀' * 12_000), repository: Fixtures::REPOSITORY) }.to raise_error(AgentWorker::TaskError)
  end

  it 'accepts compact task JSON exactly at the byte limit' do
    task = fixture.task.merge('prompt' => 'p' * 16_000, 'context' => '😀' * 5900)
    task['context'] += 'c' * (40_000 - JSON.generate(task).bytesize)
    expect(JSON.generate(task).bytesize).to eq(40_000)
    path = fixture.root / 'task.json'
    path.binwrite(JSON.generate(task))
    expect(described_class.load_task(path, repository: Fixtures::REPOSITORY)).to eq(task)
  end

  it 'fits multibyte results into transport while retaining useful questions', :aggregate_failures do
    result = { 'version' => 1, 'task_id' => '123', 'status' => 'needs_input', 'summary' => '説明' * 4000,
               'questions' => Array.new(10) { "Which layout is expected? #{'😀' * 1970}" },
               'validation' => { 'status' => 'not_run', 'summary' => '未実行' * 1300 } }
    expect(JSON.generate(result).bytesize).to be > 40_000
    payload = described_class.encode_result(result)
    expect(payload.bytesize).to be <= 40_000
    decoded = JSON.parse(payload)
    expect(decoded).to include('status' => 'needs_input', 'summary' => include('shortened'))
    expect(decoded['questions']).to all(start_with('Which layout is expected? '))
    expect(decoded['questions'].map(&:length)).to all(be_between(1, 2000))
    expect(decoded['summary'].length).to be <= 8000
    expect(result['summary'].length).to eq(8000)
  end

  it 'rejects invalid model text before serialization' do
    ['', " \t\n", "\u001c\u001d\u001e\u001f", "\u0085\u00a0", "bad\0text", "escaped \xed\xa0\x80".dup.force_encoding(Encoding::UTF_8)].each do |value|
      %w[summary questions].each do |field|
        result = { 'status' => 'needs_input', 'summary' => 'Need context', 'questions' => ['Which layout?'],
                   'validation' => { 'status' => 'not_run', 'summary' => 'Not run' } }
        result[field] = field == 'questions' ? [value] : value
        expect { described_class.validate_agent_result(result) }.to raise_error(AgentWorker::TaskError)
      end
    end
  end

  it 'treats malformed task Unicode as a controlled failure' do
    %w[prompt context].each do |field|
      path = fixture.root / 'invalid-task.json'
      path.write(JSON.generate(fixture.task.merge(field => 'REPLACEME')).sub('REPLACEME', 'escaped \\ud800'))
      expect { described_class.load_task(path, repository: Fixtures::REPOSITORY) }.to raise_error(AgentWorker::TaskError)
    end
  end

  it 'rejects raw malformed UTF-8 in every task field before applying regular expressions' do
    %w[task_id commit prompt context].each do |field|
      task = fixture.task.merge(field => 'REPLACEME')
      path = fixture.root / 'invalid-bytes.json'
      path.binwrite(JSON.generate(task).b.sub('REPLACEME', "\xff".b))
      expect { described_class.load_task(path, repository: Fixtures::REPOSITORY) }.to raise_error(AgentWorker::TaskError, /UTF-8 JSON/)
    end
  end

  it 'returns a failure and patch for malformed model Unicode' do
    fixture.write_agent(malformed_json: '{"structured_output":{"status":"completed","summary":"Bad Unicode: \\ud800","questions":[]}}')
    expect(fixture.worker.run).to eq(1)
    expect(fixture.result['status']).to eq('failed')
    expect(fixture.result['summary']).to match(/invalid summary|valid JSON/)
    expect((fixture.output / 'changes.patch').binread).to include('added.txt')
    expect(fixture.output / 'evidence/verify.log').not_to exist
  end

  it 'keeps shortened questions nonblank' do
    result = described_class.validate_agent_result('status' => 'needs_input', 'summary' => "#{"\t" * 7999}?", 'questions' => ["#{"\t" * 1999}?"] * 10,
                                                   'validation' => { 'status' => 'not_run', 'summary' => 'Not run' })
    result.merge!('version' => 1, 'task_id' => '123', 'validation' => { 'status' => 'not_run', 'summary' => 'Not run' })
    expect(JSON.parse(described_class.encode_result(result))).to include('summary' => '?', 'questions' => ['?'] * 10)
  end

  it 'requires questions exactly when the model needs input' do
    result = { 'status' => 'needs_input', 'summary' => 'Need help', 'questions' => [],
               'validation' => { 'status' => 'not_run', 'summary' => 'Not run' } }
    expect { described_class.validate_agent_result(result) }.to raise_error(AgentWorker::TaskError, /Only a needs_input/)
    expect do
      described_class.validate_agent_result(result.merge('status' => 'completed', 'questions' => ['Help?']))
    end.to raise_error(AgentWorker::TaskError, /Only a needs_input/)
  end

  it 'removes the dedicated key before checkout' do
    key = fixture.root / 'key'
    key.write("test-dedicated-key\n")
    key.chmod(0o600)
    expect(described_class.read_key(key)).to eq('test-dedicated-key')
    expect(key).not_to exist
  end

  it 'rejects empty or malformed key files with a controlled error' do
    ['', "\xff".b, "key\nother", 'x' * 4097].each do |contents|
      key = fixture.root / 'invalid-key'
      key.binwrite(contents)
      expect { described_class.read_key(key) }.to raise_error(AgentWorker::TaskError, /missing or malformed/)
      expect(key).to exist
    end
  end

  it 'kills the process group including children at the deadline' do
    marker = fixture.root / 'late-write'
    code = "spawn('/bin/sh', '-c', #{"sleep 1; touch #{Shellwords.escape(marker.to_s)}".dump}); sleep 10"
    expect do
      AgentWorker::Runner.new(described_class.monotonic + 0.2).run([RbConfig.ruby, '-e', code], fixture.root, {}, fixture.root / 'timeout.log')
    end.to raise_error(AgentWorker::DeadlineExceeded)
    sleep 1.1
    expect(marker).not_to exist
  end

  it 'enforces the deadline even if a child never reads stdin' do
    expect do
      AgentWorker::Runner.new(described_class.monotonic + 0.2).run([RbConfig.ruby, '-e', 'sleep 10'], fixture.root, {}, fixture.root / 'stdin.log',
                                                                   'x' * 100_000)
    end.to raise_error(AgentWorker::DeadlineExceeded)
  end

  it 'rejects oversized output' do
    expect do
      AgentWorker::Runner.new(described_class.monotonic + 5).run([RbConfig.ruby, '-e', 'puts "x" * 10_000'], fixture.root, {}, fixture.root / 'large.log',
                                                                 max_bytes: 100)
    end.to raise_error(AgentWorker::TaskError, /size limit/)
  end
end
