.DEFAULT_GOAL := default

lint: buildkite-plugin-lint rubocop shellcheck
test: buildkite-plugin-test buildkite-plugin-test-commands-are-executable

buildkite-plugin-test:
	docker run -t --rm -v "${PWD}":/plugin buildkite/plugin-tester

buildkite-plugin-test-commands-are-executable:
	docker run -t --rm -v "${PWD}":/plugin -w /plugin ruby:2.7.4 /bin/bash -c "gem install --silent rspec && rspec tests/test-that-all-files-are-executable.rb"

buildkite-plugin-lint:
	docker-compose run --rm lint

shellcheck:
	docker run -it --rm -v "${PWD}":/app -w /app koalaman/shellcheck hooks/** bin/** --exclude=SC1071

rubocop:
	docker run -t --rm -v "${PWD}":/plugin -w /plugin ruby:2.7.4 /bin/bash -c "gem install --silent rubocop && rubocop -A tests/test-that-all-files-are-executable.rb"

default: lint test
