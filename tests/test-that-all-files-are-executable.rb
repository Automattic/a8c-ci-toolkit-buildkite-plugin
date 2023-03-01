#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rspec'

RSpec.configure do |config|
  config.formatter = :documentation
end

# You might be thinking "why is this in Ruby instead of `environment.bats`?" Good question – for some reason,
# it seems that running `[ -x ]` under `bats` returns invalid results, and this was more reliable.
#
# See: https://github.com/Automattic/a8c-ci-toolkit-buildkite-plugin/pull/42
context 'All Commands Should Be Executable' do
  Dir.children('bin').map { |f| File.new(File.join('bin', f)) }.each do |file|
    it file.path do
      expect(file.stat.executable?).to be true
    end
  end
end
