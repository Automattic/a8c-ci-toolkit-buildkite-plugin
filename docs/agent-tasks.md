# Running an agent task

`run_agent_task` gives an agent a question, a repository commit and enough
context to investigate it. It prepares a fresh checkout, runs Claude Code and
saves the findings. Temporary edits are useful for reproducing a bug, so a
completed investigation can include a patch and a failing test.

Run it as a dedicated non-admin user in a disposable Mac VM. The host must
keep normal CI credentials and internal network access outside that VM, and
remove the VM when the task ends. The command does not provide isolation by
itself. Installing this toolkit does not start an agent.

The VM needs Git, Homebrew `ruby@3.4`, a reviewed Claude Code binary at
`/usr/local/bin/claude`, and the tools required by the app. Install a pinned
copy of this command and its library, owned by the VM administrator.

The command itself uses Homebrew Ruby. App commands use the task user's rbenv
shims when installed, so `.ruby-version` works without loading shell startup
files. Provision the required app Rubies under that user's `~/.rbenv`.

```sh
run_agent_task --repository example/mobile-app \
  --task task.json --output results --api-key-file model-key
```

The host chooses `--repository`; it must match the repository in `task.json`.
Clone URLs and extra commands cannot come from the task. The output directory
must be new or empty. The [task and result format](agent-task-protocol.md)
includes an example request and the field limits.

The command reads and removes the key file before running repository code.
Use a dedicated model key with a spend limit: code inside the VM can still
access it. Runs have a deadline, at most 80 model turns and a $20 model budget.
Inherited credentials, Ruby startup settings and user model settings are
excluded; Claude runs in bare mode with unattended command execution.

When it finishes, look in `results/`:

- `result.json` explains the findings, checks and any questions.
- `evidence/` contains useful logs and screenshots, when applicable.
- `changes.patch` preserves temporary edits, including new files and local commits.

Questions end the task. Supply the missing context in a new request. The host
collects these files before destroying the VM and checks the job status too:
cancellation or a hard failure may leave no report.

## Preparing an app

The chosen commit needs `.buildkite/agent/prepare.sh` and a `README.md` with
the app's build and investigation instructions. Preparation runs through
`/bin/bash` from the checkout. It should fail if the environment is unsuitable.
Use `AGENT_STATE_DIR` for temporary files and `AGENT_OUTPUT_DIR/evidence` for
logs. Both paths are outside the checkout.

Put platform details, such as simulator selection, in that adapter. The agent
chooses the checks that help answer the question; there is no mandatory final
green build, and the runner never pushes or opens a PR.

## Preparing a change

Use `mode: "change"` when the request is to prepare a fix. The adapter also needs
`verify.sh`, which runs after the agent finishes. A change is complete only if
that check passes. The report can include a public title, description and testing
summary for a separate publisher; keep conversation details out of those fields.

Publishing remains the host’s responsibility. It must validate the patch and
report before using any write credentials. This command only prepares the files.
Investigations still need no final green check and their edits stay private.

The runner tests use temporary Git repositories and a fake model executable.
Run `make test lint` to exercise the flow without a model service or app tools.
