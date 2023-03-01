#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rspec'

RSpec.configure do |config|
  config.formatter = :documentation
end

context 'All Commands Should Be Executable' do
  Dir.children('bin').map { |f| File.new(File.join('bin', f)) }.each do |file|
    it file.path do
      expect(file.stat.executable?).to be true
    end
  end
end
