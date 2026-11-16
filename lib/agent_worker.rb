# frozen_string_literal: true

require 'etc'
require 'English'
require 'fileutils'
require 'json'
require 'optparse'
require 'tempfile'
require 'time'

# Runs one bounded investigation inside a disposable, unprivileged worker VM.
module AgentWorker
  REPOSITORY_NAME = %r{\A[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9][A-Za-z0-9_.-]*\z}
  MAX_TASK_BYTES = 40_000
  MAX_RESULT_BYTES = 40_000
  MAX_LOG_BYTES = 8 * 1024 * 1024
  MAX_PATCH_BYTES = 16 * 1024 * 1024
  MAX_DIAGNOSTIC_BYTES = 16 * 1024
  SAFE_PATH = '/opt/homebrew/opt/ruby@3.4/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin'
  AGENT_SCHEMA = {
    type: 'object', properties: {
      status: { type: 'string', enum: %w[completed failed needs_input] },
      summary: { type: 'string', minLength: 1, maxLength: 8000 },
      questions: { type: 'array', maxItems: 10, items: { type: 'string', minLength: 1, maxLength: 2000 } },
      validation: {
        type: 'object', properties: {
          status: { type: 'string', enum: %w[passed failed not_run] },
          summary: { type: 'string', minLength: 1, maxLength: 4000 }
        }, required: %w[status summary], additionalProperties: false
      }
    }, required: %w[status summary questions validation], additionalProperties: false
  }.freeze

  class TaskError < StandardError; end
  class DeadlineExceeded < TaskError; end

  module_function

  def monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def valid_text?(value, limit, allow_blank: false)
    value.is_a?(String) && value.valid_encoding? && value.length <= limit && !value.include?("\0") &&
      (allow_blank || !value.match?(/\A[[:space:]\u001c-\u001f]*\z/))
  end

  def exact_fields?(value, required, optional = [])
    value.is_a?(Hash) && (required - value.keys).empty? && (value.keys - required - optional).empty?
  end

  def validate_task(task, repository:)
    raise TaskError, 'The trusted repository must be a GitHub owner/name.' unless valid_text?(repository, 255) && REPOSITORY_NAME.match?(repository)

    fields = %w[version task_id mode repository commit prompt context timeout_seconds]
    raise TaskError, 'Task must contain exactly the version 1 fields.' unless exact_fields?(task, fields)
    raise TaskError, 'Unsupported task version.' unless task['version'].is_a?(Integer) && task['version'] == 1

    raise TaskError, 'Only investigation tasks are supported.' unless task['mode'] == 'investigate'

    id = task['task_id']
    raise TaskError, 'Invalid task ID.' unless valid_text?(id, 64) && /\A(?:[0-9]+|[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})\z/.match?(id)
    raise TaskError, 'Task repository is not allowed.' unless task['repository'] == repository
    raise TaskError, 'A full lowercase commit SHA is required.' unless valid_text?(task['commit'], 40) && /\A[0-9a-f]{40}\z/.match?(task['commit'])
    raise TaskError, 'Invalid task text.' unless valid_text?(task['prompt'], 16_000) && valid_text?(task['context'], 16_000, allow_blank: true)
    raise TaskError, 'Task timeout must be between 60 and 3600 seconds.' unless task['timeout_seconds'].is_a?(Integer) && (60..3600).cover?(task['timeout_seconds'])

    raise TaskError, 'Task exceeds the byte limit.' if JSON.generate(task).bytesize > MAX_TASK_BYTES

    task
  end

  def load_task(path, repository:)
    raw = File.binread(path, MAX_TASK_BYTES + 1)
    raise TaskError, 'Task exceeds the byte limit.' if raw.bytesize > MAX_TASK_BYTES

    validate_task(parse_json(raw), repository: repository)
  rescue JSON::ParserError, EncodingError
    raise TaskError, 'Task is not valid UTF-8 JSON.'
  end

  def parse_json(raw)
    text = raw.dup.force_encoding(Encoding::UTF_8)
    raise JSON::ParserError, 'Invalid UTF-8 JSON.' unless text.valid_encoding?

    JSON.parse(text)
  end

  def validate_agent_result(result)
    raise TaskError, 'Agent did not return the required result fields.' unless exact_fields?(result, %w[status summary questions validation])
    raise TaskError, 'Agent returned an invalid status.' unless %w[completed failed needs_input].include?(result['status'])
    raise TaskError, 'Agent returned an invalid summary.' unless valid_text?(result['summary'], 8000)

    questions = result['questions']
    raise TaskError, 'Agent returned invalid questions.' unless questions.is_a?(Array) && questions.length <= 10 && questions.all? { |question| valid_text?(question, 2000) }
    raise TaskError, 'Only a needs_input result may contain questions, and must contain at least one.' if (result['status'] == 'needs_input') == questions.empty?

    checks = result['validation']
    raise TaskError, 'Agent returned invalid check results.' unless exact_fields?(checks, %w[status summary]) && %w[passed failed not_run].include?(checks['status']) && valid_text?(checks['summary'], 4000)

    result.merge('summary' => strip_text(result['summary']), 'questions' => questions.map { |question| strip_text(question) })
  end

  def strip_text(value)
    value.gsub(/\A[[:space:]\u001c-\u001f]+|[[:space:]\u001c-\u001f]+\z/, '')
  end

  def encode_result(result)
    result = result.merge('questions' => result['questions'].dup, 'validation' => result['validation'].dup)
    encoded = -> { "#{JSON.generate(result)}\n" }
    return encoded.call if encoded.call.bytesize <= MAX_RESULT_BYTES

    marker = "\n[Result shortened to fit the response limit.]"
    summary = result['summary'][0, 8000 - marker.length]
    result['summary'] = summary + marker
    while encoded.call.bytesize > MAX_RESULT_BYTES
      fields = [['summary', summary], ['validation', result['validation']['summary']]] + result['questions'].each_with_index.map { |q, i| [i, q] }
      key, value = fields.max_by { |_name, text| JSON.generate(text).bytesize }
      shortened = value[0, [1, value.length / 2].max]
      case key
      when 'summary'
        summary = shortened
        result['summary'] = summary + marker
      when 'validation'
        result['validation']['summary'] = shortened
      else
        result['questions'][key] = shortened
      end
    end
    encoded.call
  end

  def clean_environment(home, state, output)
    # No inherited Buildkite, GitHub, AWS, SSH agent or user model configuration.
    {
      'HOME' => home.to_s, 'PATH' => SAFE_PATH, 'LANG' => 'en_US.UTF-8',
      'TMPDIR' => File.join(state, 'tmp'), 'CI' => '1', 'GIT_TERMINAL_PROMPT' => '0',
      'GIT_CONFIG_NOSYSTEM' => '1', 'GIT_CONFIG_GLOBAL' => File::NULL,
      'AGENT_OUTPUT_DIR' => output.to_s, 'AGENT_STATE_DIR' => state.to_s,
      'CLAUDE_CONFIG_DIR' => File.join(state, 'claude'), 'DISABLE_AUTOUPDATER' => '1'
    }
  end

  def open_output(path, &)
    File.open(path, File::WRONLY | File::CREAT | File::TRUNC | File::NOFOLLOW, 0o600, &)
  end

  # Commands get a process group, a deadline and bounded file output. Stdin is a
  # temporary file so a child that never reads cannot block deadline enforcement.
  class Runner
    attr_reader :deadline

    def initialize(deadline)
      @deadline = deadline
    end

    def self.stop(pid)
      Process.kill('TERM', -pid)
      until AgentWorker.monotonic >= (finish ||= AgentWorker.monotonic + 2)
        break if Process.waitpid(pid, Process::WNOHANG)

        sleep 0.02
      end
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    ensure
      begin
        Process.kill('KILL', -pid)
      rescue Errno::ESRCH
        nil
      end
      begin
        Process.waitpid(pid)
      rescue Errno::ECHILD
        nil
      end
    end

    def run(command, cwd, env, log, stdin = nil, max_bytes: MAX_LOG_BYTES, stderr_log: nil, cleanup_children: false)
      raise DeadlineExceeded, 'Task deadline reached.' if AgentWorker.monotonic >= deadline

      AgentWorker.open_output(log) do |output|
        Tempfile.create('agent-input') do |input|
          input.write(stdin) if stdin
          input.rewind
          errors = AgentWorker.open_output(stderr_log) if stderr_log
          pid = Process.spawn(env, *command, chdir: cwd, unsetenv_others: true, pgroup: true,
                                             in: stdin ? input : File::NULL, out: output, err: errors || output)
          done = nil
          begin
            loop do
              done = Process.waitpid2(pid, Process::WNOHANG)
              raise TaskError, 'Command output exceeded its size limit.' if output.size > max_bytes || (errors && errors.size > max_bytes)
              return done[1].exitstatus || (128 + done[1].termsig) if done
              raise DeadlineExceeded, 'Task deadline reached.' if AgentWorker.monotonic >= deadline

              sleep (deadline - AgentWorker.monotonic).clamp(0.001, 0.1)
            end
          ensure
            self.class.stop(pid) if $ERROR_INFO || cleanup_children || !done
            errors&.close
          end
        end
      end
    end
  end

  # The disposable VM is the security boundary for repository and model code.
  class Worker
    attr_reader :task, :output, :result

    def initialize(task, output, api_key, repository:, repository_url: nil, agent: '/usr/local/bin/claude')
      @task = AgentWorker.validate_task(task, repository: repository)
      @output = File.absolute_path(output)
      @api_key = api_key
      @repository_url = repository_url || "https://github.com/#{repository}.git"
      @agent = agent
      @result = {
        'version' => 1, 'task_id' => task['task_id'], 'status' => 'failed',
        'summary' => 'The task did not finish.', 'questions' => [],
        'validation' => { 'status' => 'not_run', 'summary' => 'App verification has not run.' }
      }
    end

    def command(command, phase, env: @env, stdin: nil)
      @runner.run(command, @checkout, env, File.join(output, 'evidence', "#{phase}.log"), stdin)
    end

    def git(*arguments)
      ['git', '-c', 'core.hooksPath=/dev/null', '-c', 'credential.helper=', *arguments]
    end

    def prepare_checkout
      [git('init', '--quiet', '.'), git('remote', 'add', 'origin', @repository_url),
       git('fetch', '--quiet', '--depth=1', 'origin', task['commit']), git('checkout', '--quiet', '--detach', task['commit'])].each do |cmd|
        raise TaskError, 'Could not check out the requested public repository commit.' unless command(cmd, 'checkout').zero?
      end
      @has_checkout = true
      %w[prepare.sh].each do |script|
        path = File.join(@checkout, '.buildkite', 'agent', script)
        raise TaskError, 'This commit does not have the required app adapter.' unless File.file?(path) && !File.symlink?(path)
      end
      @adapter = File.join(@state, 'adapter')
      FileUtils.cp_r(File.join(@checkout, '.buildkite', 'agent'), @adapter, dereference_root: false)
    end

    def agent_prompt
      remaining = [0, (@runner.deadline - AgentWorker.monotonic).to_i].max
      deadline = (Time.now + remaining).utc.iso8601
      'You are investigating one issue in a disposable VM. ' \
        "About #{remaining} seconds remain until #{deadline}; leave time to write your report. " \
        'Read AGENTS.md, CLAUDE.md if present, and .buildkite/agent/README.md before working. ' \
        'You may edit this disposable checkout to add a failing test or isolate the cause. ' \
        'Do not push, create PRs, change external services, or use production accounts. ' \
        'Run the checks that help answer the question; a full build is not always necessary. ' \
        'A reproduced failure can be a completed investigation. Report whether you reproduced the issue, ' \
        'what you tried, the evidence, and what remains uncertain. ' \
        'In validation, record the actual check outcome (passed, failed or not_run) and the commands used. ' \
        'Do not claim tests passed when a failing test is your evidence. ' \
        'Save useful logs and, when relevant, screenshots under AGENT_OUTPUT_DIR/evidence. ' \
        'If context, credentials or a decision are required, stop with needs_input and specific questions. ' \
        'A follow-up starts a new task; do not wait for an interactive answer. ' \
        'Do not change task/result files or verification scripts to make checks pass. ' \
        "Return a concise structured result.\n\n" \
        "Task:\n#{task['prompt']}\n\nProvided context:\n#{task['context']}"
    end

    def save_agent_errors(path)
      key = @api_key.b
      data = File.open(path, File::RDONLY | File::NOFOLLOW | File::NONBLOCK) do |stream|
        next unless stream.stat.file?

        stream.seek([0, stream.size - MAX_DIAGNOSTIC_BYTES - key.bytesize].max)
        (stream.binmode.read(MAX_DIAGNOSTIC_BYTES + key.bytesize) || ''.b).gsub(key, '*' * key.bytesize)
      end
      return unless data

      data = data.byteslice([0, data.bytesize - MAX_DIAGNOSTIC_BYTES].max, MAX_DIAGNOSTIC_BYTES).force_encoding(Encoding::UTF_8).scrub('')
      AgentWorker.open_output(File.join(output, 'evidence', 'agent-errors.log')) do |stream|
        stream.write(data.empty? ? "The coding agent did not write any stderr diagnostics.\n" : data)
      end
    end

    def run_agent
      response_path = File.join(@state, 'model-response.json')
      errors_path = File.join(@state, 'model-errors.log')
      cmd = [@agent, '--bare', '--print', '--permission-mode', 'bypassPermissions', '--output-format', 'json',
             '--json-schema', JSON.generate(AGENT_SCHEMA), '--no-session-persistence', '--max-turns', '80', '--max-budget-usd', '20']
      begin
        code = @runner.run(cmd, @checkout, @env.merge('ANTHROPIC_API_KEY' => @api_key), response_path, agent_prompt,
                           max_bytes: 1024 * 1024, stderr_log: errors_path, cleanup_children: true)
      ensure
        begin
          save_agent_errors(errors_path)
        rescue SystemCallError
          nil # Missing diagnostics must not replace the task's original failure.
        end
      end
      raise TaskError, 'The coding agent failed; see evidence/agent-errors.log for CLI diagnostics.' unless code.zero?

      response = AgentWorker.parse_json(File.binread(response_path))
      raise TaskError, 'The coding agent reported an error.' unless response.is_a?(Hash) && !response['is_error']

      AgentWorker.validate_agent_result(response['structured_output'])
    rescue JSON::ParserError, EncodingError
      raise TaskError, 'The coding agent did not return valid JSON.'
    end

    def save_patch
      # A separate index captures added files and changes even after local commits.
      env = @env.merge('GIT_INDEX_FILE' => File.join(@state, 'patch-index'))
      runner = Runner.new(AgentWorker.monotonic + 15)
      [['read-tree', task['commit']], ['add', '--all', '--', '.']].each do |arguments|
        code = runner.run(git(*arguments), @checkout, env, File.join(@state, 'patch.log'))
        raise TaskError, "Could not preserve the task's changes." unless code.zero?
      end
      code = runner.run(git('diff', '--cached', '--binary', '--no-ext-diff', '--no-textconv', task['commit'], '--', '.'),
                        @checkout, env, File.join(output, 'changes.patch'), max_bytes: MAX_PATCH_BYTES)
      raise TaskError, "Could not preserve the task's changes." unless code.zero?
    end

    def run
      raise TaskError, 'Output must be a new or empty directory, not a symlink.' if File.symlink?(output)

      FileUtils.mkdir_p(output, mode: 0o700)
      raise TaskError, 'Output directory must be empty.' unless Dir.empty?(output)

      FileUtils.mkdir_p(File.join(output, 'evidence'), mode: 0o700)
      @state = Dir.mktmpdir('agent-state-', File.dirname(output))
      @checkout = File.join(@state, 'checkout')
      FileUtils.mkdir_p([File.join(@state, 'tmp'), @checkout], mode: 0o700)
      @has_checkout = false
      @env = AgentWorker.clean_environment(Etc.getpwuid(Process.uid).dir, @state, output)
      @runner = Runner.new(AgentWorker.monotonic + task['timeout_seconds'])
      begin
        prepare_checkout
        raise TaskError, 'App preparation failed; see evidence/prepare.log.' unless command(['/bin/bash', File.join(@adapter, 'prepare.sh')], 'prepare').zero?

        result.merge!(run_agent)
      rescue TaskError, SystemCallError => e
        fail_result(e)
      ensure
        @api_key = nil
        if @has_checkout
          begin
            save_patch
          rescue TaskError, SystemCallError => e
            fail_result(e)
            FileUtils.rm_f(File.join(output, 'changes.patch'))
          end
        end
        AgentWorker.open_output(File.join(output, 'result.json')) { |stream| stream.write(AgentWorker.encode_result(result)) }
      end
      result['status'] == 'failed' ? 1 : 0
    end

    def fail_result(error)
      result.merge!('status' => 'failed', 'summary' => error.message[0, 8000], 'questions' => [])
    end
  end

  def require_unprivileged_user
    return unless Process.uid.zero? || Process.euid.zero? || (RUBY_PLATFORM.include?('darwin') && Process.groups.include?(Etc.getgrnam('admin').gid))

    raise TaskError, 'Run the worker as the dedicated non-admin VM user.'
  end

  def read_key(path)
    key = File.open(path, File::RDONLY | File::NOFOLLOW) do |stream|
      stream.set_encoding(Encoding::UTF_8)
      stream.each_char.take(4097).join
    end
    raise TaskError, 'The dedicated model key is missing or malformed.' unless key.valid_encoding?

    key = strip_text(key)
    raise TaskError, 'The dedicated model key is missing or malformed.' if key.empty? || !key.valid_encoding? || key.length > 4096 || key.include?("\n")

    File.unlink(path)
    key
  end

  def parse_options(argv, required, optional = [])
    options = {}
    parser = OptionParser.new do |opts|
      (required + optional).each { |name| opts.on("--#{name} VALUE") { |value| options[name.tr('-', '_').to_sym] = value } }
    end
    parser.parse!(argv)
    raise OptionParser::InvalidArgument, argv.join(' ') unless argv.empty?

    required.each { |name| raise OptionParser::MissingArgument, "--#{name}" unless options.key?(name.tr('-', '_').to_sym) }
    options
  end

  def main(argv = ARGV)
    options = parse_options(argv, %w[repository task output api-key-file])
    require_unprivileged_user
    task = load_task(options[:task], repository: options[:repository])
    key = read_key(options[:api_key_file])
    %w[TERM INT].each { |signal| Signal.trap(signal) { raise TaskError, 'Task cancelled.' } }
    Worker.new(task, options[:output], key, repository: options[:repository]).run
  rescue TaskError, SystemCallError, OptionParser::ParseError => e
    warn e.message
    1
  end
end

exit AgentWorker.main if $PROGRAM_NAME == __FILE__
