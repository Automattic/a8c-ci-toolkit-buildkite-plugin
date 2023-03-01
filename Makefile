.DEFAULT_GOAL := default

lint:
	docker run -it --rm -v "${PWD}":/plugin:ro buildkite/plugin-tester

test:
	docker run -t --rm -v "${PWD}":/plugin buildkite/plugin-tester
	docker run -t --rm -v "${PWD}":/plugin -w /plugin ruby:2.7.4 /bin/bash -c "gem install rspec && rspec tests/test-that-all-files-are-executable.rb"

shellcheck:
	docker run -it --rm -v "${PWD}":/app -w /app koalaman/shellcheck hooks/** bin/** --exclude=SC1071

default: lint test shellcheck
