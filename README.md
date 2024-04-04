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
      - automattic/a8c-ci-toolkit#3.2.1:
          bucket: a8c-ci-cache # optional
```

Don't forget to verify what [the latest release](https://github.com/Automattic/a8c-ci-toolkit-buildkite-plugin/releases/latest) is and use that value instead of `3.2.1`.

## Configuration

### `bucket` (Optional, string)

The name of the S3 bucket to fallback to if the `CACHE_BUCKET_NAME` environment variable is not set in the CI host. Used by `save_cache` and `restore_cache`.

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

## Releasing

1. Make a PR to update references of the version number in this `README.md` and to update the `CHANGELOG.md` according to the `<!-- instructions -->` to prepare it for a new release.
2. Merge the PR
3. Create a new GitHub Release, named after the new version number, and pasting the content of the `CHANGELOG.md` section corresponding to the new version as description. This will have the side effect of creating a `git tag` too, which is all we need for the new version to be available.
