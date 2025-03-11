.DEFAULT_GOAL := default

RUBY_VERSION := $(shell cat .ruby-version)

default: lint test
lint: buildkite-plugin-lint rubocop shellcheck
test: buildkite-plugin-test rspec

docker_run := docker run -t --rm -v "${PWD}"/:/plugin -w /plugin

buildkite-plugin-lint:
	@echo ~~~ 🕵️ Plugin Linter
	$(docker_run) buildkite/plugin-linter --id automattic/a8c-ci-toolkit

shellcheck:
	@echo ~~~ 🕵️ ShellCheck
	$(docker_run) koalaman/shellcheck $(shell find hooks bin -type f -not -name "*.ps1") --exclude=SC1071

rubocop:
	@echo ~~~ 🕵️ Rubocop
	$(docker_run) ruby:$(RUBY_VERSION) /bin/bash -c \
	  "bundle install && bundle exec rubocop -A tests/test_that_all_files_are_executable.rb"

buildkite-plugin-test:
	@echo ~~~ 🔬 Plugin Tester
	$(docker_run) buildkite/plugin-tester

rspec:
	@echo ~~~ 🔬 Rspec
	$(docker_run) ruby:$(RUBY_VERSION) /bin/bash -c \
	  "gem install --silent rspec -v 3.13.0 && rspec tests/test_that_all_files_are_executable.rb"
