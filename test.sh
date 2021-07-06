#!/bin/bash

docker-compose run --rm lint
docker-compose run --rm tests

# Test hooks
shellcheck hooks/*
