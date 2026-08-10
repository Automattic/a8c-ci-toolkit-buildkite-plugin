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
      - automattic/a8c-ci-toolkit#6.2.0:
          bucket: a8c-ci-cache # optional
```

Don't forget to verify what [the latest release](https://github.com/Automattic/a8c-ci-toolkit-buildkite-plugin/releases/latest) is and use that value instead of `6.2.0`.

## Configuration

### `bucket` (Optional, string)

The name of the S3 bucket to fallback to if the `CACHE_BUCKET_NAME` environment variable is not set in the CI host. Used by `save_cache` and `restore_cache`.

## Using the commands inside a Docker container

The commands are made available by adding this plugin's `bin/` directory to the `$PATH` of the CI job. A step that runs its command inside a container — via the [`docker` plugin](https://github.com/buildkite-plugins/docker-buildkite-plugin), say — doesn't get them, because the plugin's files live on the agent host rather than in the image.

For those steps, this plugin exports `$A8C_CI_TOOLKIT_PLUGIN_DIR`, the absolute path to its own checkout on the host. Mount that into the container and put its `bin/` on the `$PATH` there:

```yml
steps:
  - command: |
      export PATH="$$PATH:/a8c-ci-toolkit/bin"

      checkout_release_branch "$RELEASE_VERSION"
    plugins:
      - automattic/a8c-ci-toolkit#6.2.0
      - docker#v5.13.0:
          image: node:22-bookworm
          expand-volume-vars: true
          volumes:
            - "$$A8C_CI_TOOLKIT_PLUGIN_DIR:/a8c-ci-toolkit:ro"
```

Three things make that work:

- Listing this plugin alongside `docker`. Every plugin's `environment` hook runs before any plugin's `command` hook, so the variable is exported before the `docker` plugin assembles its `docker run` arguments — whichever order the two are listed in.
- `expand-volume-vars: true`, without which the `docker` plugin passes the `volumes` entry through verbatim instead of interpolating the variable.
- The `$$` in both `$$A8C_CI_TOOLKIT_PLUGIN_DIR` and `$$PATH`. A single `$` is resolved when the pipeline is uploaded, where neither variable has a value yet; `$$` defers it to when the job runs. Note that this is only needed if you write that line directly in the `.yml`; if instead your `command:` calls a dedicated `.sh` script you can do `export PATH=$PATH:/a8c-ci-toolkit/bin` in that `.sh` file instead of in the `.yml` and avoid the need for the `$$` escape.

Only the commands whose dependencies the image provides will work, of course — `checkout_release_branch` needs `bash` and `git` inside the container, for instance.

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
