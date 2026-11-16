# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require 'pathname'
require 'rbconfig'
require 'shellwords'
require 'socket'
require 'tmpdir'
require_relative '../../lib/agent_worker'

RSpec.configure do |config|
  config.order = :random
  config.expect_with(:rspec) { |expectations| expectations.syntax = :expect }
end

# Temporary repositories and subprocesses for the runner’s integration tests.
module Fixtures
  REPOSITORY = 'example/mobile-app'
  def self.command(*command, cwd: nil, env: {}, data: '')
    output, errors, status = Open3.capture3(env, *command, chdir: cwd || Dir.pwd, stdin_data: data)
    raise "Fixture command failed: #{command.inspect}\n#{errors}" unless status.success?

    output
  end

  # An app adapter and model executable with controllable outcomes.
  class Worker
    attr_reader :root, :repo, :adapter, :agent, :output, :sha
    attr_accessor :repository, :mode

    def initialize
      @repository = REPOSITORY
      @mode = 'investigate'
      @root = Pathname(Dir.mktmpdir)
      @repo = root / 'source'
      repo.mkdir
      git('init', '--quiet')
      git('config', 'user.name', 'Fixture')
      git('config', 'user.email', 'fixture@example.invalid')
      @adapter = repo / '.buildkite/agent'
      adapter.mkpath
      (adapter / 'prepare.sh').write("set -eu\nprintf prepared > \"$AGENT_STATE_DIR/prepared\"\n")
      (adapter / 'verify.sh').write("set -eu\ntest \"$(cat \"$AGENT_STATE_DIR/prepared\")\" = prepared\ntest -f added.txt\n")
      (repo / 'tracked.txt').write("before\n")
      commit
      @agent = root / 'claude'
      @output = root / 'output'
      write_agent
    end

    def close
      FileUtils.remove_entry(root)
    end

    def git(*)
      Fixtures.command('/usr/bin/git', *, cwd: repo).strip
    end

    def commit
      git('add', '--all')
      git('commit', '--quiet', '-m', 'Fixture')
      @sha = git('rev-parse', 'HEAD')
    end

    def task
      { 'version' => 1, 'task_id' => '123', 'mode' => mode, 'repository' => repository, 'commit' => sha,
        'prompt' => 'Investigate a bug', 'context' => 'Useful context', 'timeout_seconds' => 60 }
    end

    def write_agent(status: 'completed', exit_code: 0, edit_verifier: false, make_changes: true,
                    summary: 'Investigated the issue.', diagnostic: 'A diagnostic belongs on stderr',
                    malformed_json: nil, local_commit: false, failing_check: false)
      result = { 'status' => status, 'summary' => summary, 'questions' => status == 'needs_input' ? ['Which layout is expected?'] : [],
                 'validation' => { 'status' => failing_check ? 'failed' : 'not_run',
                                   'summary' => failing_check ? 'ruby reproduce.rb failed as expected; see evidence/reproduce.log.' : 'No checks needed.' } }

      result['pull_request'] = if mode == 'change' && status == 'completed'
                                 { 'title' => 'Fix the editor', 'description' => 'The editor now keeps the button visible.',
                                   'testing' => 'Checked the editor in the simulator.' }
                               end
      response = malformed_json || JSON.generate('structured_output' => result, 'is_error' => false)
      agent.write(<<~SCRIPT)
        #!#{RbConfig.ruby} --disable-gems
        raise 'missing key' unless ENV.fetch('ANTHROPIC_API_KEY') == 'test-dedicated-key'
        raise 'inherited credentials' if ENV.keys.any? { |key| key.start_with?('BUILDKITE_', 'AWS_', 'GH_', 'GITHUB_', 'RUBYOPT', 'RUBYLIB') }
        raise 'inherited SSH agent' if ENV.key?('SSH_AUTH_SOCK')
        raise 'missing bare/schema arguments' unless ARGV.include?('--bare') && ARGV.include?('--json-schema')
        raise 'missing prompt' unless $stdin.read.include?('Investigate a bug')
        if #{make_changes}
          File.write('tracked.txt', "after\\n")
          File.binwrite('added.txt', "new\\x00binary\\n")
        end
        File.write('.buildkite/agent/verify.sh', "exit 0\\n") if #{edit_verifier}
        if #{local_commit}
          system('/usr/bin/git', 'add', '--all', exception: true)
          system('/usr/bin/git', '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '--quiet', '-m', 'Local edit', exception: true)
        end
        if #{failing_check}
          File.write('reproduce.rb', "abort 'Reproduced the issue'\\n")
          system(#{RbConfig.ruby.dump}, 'reproduce.rb', out: File.join(ENV.fetch('AGENT_OUTPUT_DIR'), 'evidence/reproduce.log'), err: [:child, :out])
          raise 'expected the check to fail' if $?.success?
        end
        $stderr.write(#{diagnostic.dump})
        puts #{response.dump}
        exit #{exit_code}
      SCRIPT
      agent.chmod(0o700)
    end

    def worker
      AgentWorker::Worker.new(task, output, 'test-dedicated-key', repository: repository, repository_url: repo.to_s, agent: agent.to_s)
    end

    def result
      JSON.parse((output / 'result.json').read)
    end
  end
end
