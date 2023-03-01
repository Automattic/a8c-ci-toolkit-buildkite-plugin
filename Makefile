.DEFAULT_GOAL := default

lint:
	docker-compose run --rm lint

test:
	docker run -it --rm -v `pwd`:/plugin:ro buildkite/plugin-tester

default: lint test
