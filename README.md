# CI Toolkit Buildkite Plugin

A library of commonly used commands for your CI builds.

## Example

For a directory structure that looks like:

```
my-project/
├── node_modules/
├── package.json
├── package-lock.json

```

Add the following to your `pipeline.yml`:

```yml
steps:
  - command: |
      # To persist the cache
      save_cache node_modules/ $(hash_file package-lock.json)

      # To restore the cache, if present
      restore_cache $(hash_file package-lock.json)

    plugins:
      - automattic/a8c-ci-toolkit#2.15.0
```

Don't forget to verify what [the latest release](https://github.com/Automattic/a8c-ci-toolkit-buildkite-plugin/releases/latest) is and use that value instead of `2.15.0`.

## Configuration

There are no configuration options for this plugin

## Developing

To run the linter and tests:

```shell
make lint
make test
```

## Contributing

1. Fork the repo
2. Make the changes
3. Run the tests
4. Commit and push your changes
5. Send a pull request
