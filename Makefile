.DEFAULT_GOAL := default

default: lint test
lint: buildkite-plugin-lint rubocop shellcheck
test: buildkite-plugin-test rspec

docker_run := docker run -t --rm -v "${PWD}"/:/plugin:ro -w /plugin

buildkite-plugin-lint:
	@echo ~~~ 🕵️ Plugin Linter
	$(docker_run) buildkite/plugin-linter --id automattic/a8c-ci-toolkit

shellcheck:
	@echo ~~~ 🕵️ ShellCheck
	$(docker_run) koalaman/shellcheck hooks/** bin/** --exclude=SC1071

rubocop:
	@echo ~~~ 🕵️ Rubocop
	$(docker_run) ruby:2.7.4 /bin/bash -c \
	  "gem install --silent rubocop && rubocop -A tests/test-that-all-files-are-executable.rb"

buildkite-plugin-test:
	@echo ~~~ 🔬 Plugin Tester
	$(docker_run) buildkite/plugin-tester

rspec:
	@echo ~~~ 🔬 Rspec
	$(docker_run) ruby:2.7.4 /bin/bash -c \
	  "gem install --silent rspec && rspec tests/test-that-all-files-are-executable.rb"
