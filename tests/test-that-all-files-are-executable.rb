#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rspec'

RSpec.configure do |config|
  config.formatter = :documentation
end

# You might be thinking "why is this in Ruby instead of `environment.bats`?" Good question – for some reason,
# it seems that running `[ -x ]` under `bats` in Docker on a Mac returns invalid results, and this was more reliable.
#
# See: https://github.com/Automattic/a8c-ci-toolkit-buildkite-plugin/pull/42
context 'all commands should be executable' do
  Dir.glob('bin/*').each do |path|
    it path do
      expect(File.stat(path)).to be_executable, "File `#{path}` is not executable"
    end
  end
end
