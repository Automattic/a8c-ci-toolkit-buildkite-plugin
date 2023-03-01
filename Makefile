.DEFAULT_GOAL := default

lint:
	docker run -it --rm -v `pwd`:/plugin:ro buildkite/plugin-tester

test:
	docker run -it --rm -v `pwd`:/plugin:ro buildkite/plugin-tester

shellcheck:
	docker run -it --rm -v `pwd`:/app -w /app koalaman/shellcheck hooks/** bin/** --exclude=SC1071

default: lint test shellcheck
