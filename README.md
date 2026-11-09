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
      - automattic/a8c-ci-toolkit#7.1.1:
          bucket: a8c-ci-cache # optional
```

Don't forget to verify what [the latest release](https://github.com/Automattic/a8c-ci-toolkit-buildkite-plugin/releases/latest) is and use that value instead of `7.1.1`.

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
      - automattic/a8c-ci-toolkit#7.1.1
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

## Checking changed files

[`pr_changed_files`](bin/pr_changed_files) checks a Buildkite PR against its merge base.
[`commit_changed_files`](bin/commit_changed_files) checks `HEAD` against its first parent,
or an explicit `--commit` / `--base`. See their script headers for options and matching rules.

For trunk builds, the default does **not** cover earlier commits from a multi-commit push
or rebase merge, or from a previous build that was skipped, canceled or failed. The next
build could skip jobs for changes that remain untested or failing. Supply a `--base`
covering those changes, or run jobs without skipping.

Both commands return 0 when the condition holds (any files changed, or the requested
patterns matched), 1 when it doesn't, and 255 on errors. `--stdout` prints `true`/`false`
and exits 0 for either result; errors still exit 255 with no stdout. Skip only on the
expected result, so errors leave the job running:

```bash
# Skip only when every changed path is known to be irrelevant to this job.
if commit_changed_files --all-match 'docs/*' 'README.md'; then
  exit 0
fi

# With --any-match, only status 1 means no relevant changes. `if ! ...` also
# catches errors, so it isn't safe for deciding whether to skip.
result=0
pr_changed_files --any-match 'src/*' || result=$?
if [[ "$result" -eq 1 ]]; then
  exit 0
fi
# Continue with the job on a match or an error.
```

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
