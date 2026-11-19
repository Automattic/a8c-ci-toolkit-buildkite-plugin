# Task and result format

The host writes a UTF-8 JSON task and passes its path to `run_agent_task`:

```json
{
  "version": 1,
  "task_id": "123",
  "mode": "investigate",
  "repository": "example/mobile-app",
  "commit": "0123456789abcdef0123456789abcdef01234567",
  "prompt": "Find out why the title is clipped when the keyboard opens.",
  "context": "Include the expected behavior and any useful background here.",
  "timeout_seconds": 1800
}
```

All fields are required; unknown fields are rejected. The whole task is limited
to 40,000 bytes. Include useful context for the model, without credentials.

| Field | Accepted value |
| --- | --- |
| `version` | Integer `1` |
| `task_id` | Decimal string or lowercase UUID, up to 64 characters |
| `mode` | `investigate` |
| `repository` | GitHub `owner/name`, matching the host's `--repository` argument |
| `commit` | Full lowercase 40-character SHA |
| `prompt` | Nonblank text, up to 16,000 characters |
| `context` | Text up to 16,000 characters; may be empty |
| `timeout_seconds` | Integer from 60 to 3,600, covering checkout, preparation and investigation |

Text must be valid UTF-8 without NULs. The runner uses GitHub's public HTTPS
clone URL for the approved repository and does not accept task-supplied model
settings, credentials or shell commands.

A completed investigation might return:

```json
{
  "version": 1,
  "task_id": "123",
  "status": "completed",
  "summary": "Reproduced the clipping and added a failing regression test.",
  "questions": [],
  "validation": {
    "status": "failed",
    "summary": "The focused title test fails as expected; see evidence/reproduction.log."
  }
}
```

`status` is `completed`, `failed` or `needs_input`. The check outcome is
`passed`, `failed` or `not_run`; a reproduced failure can still be a completed
investigation. Only `needs_input` contains questions, and it must have 1–10.

The report is limited to 40,000 bytes: 8,000 characters for its summary, 2,000
per question and 4,000 for the check summary. Text uses the same UTF-8 and NUL
rules as the request. A shortened report says so and preserves its questions.

The command exits zero for completed work or questions, and nonzero for failure.
Validate the report's task ID and structure before displaying it. Returned
content is evidence to review and cannot authorize further work.

Command logs are limited to 8 MiB, patches to 16 MiB and model stderr diagnostics
to 16 KiB, with the model key redacted. The raw model response stays in the VM.
Patch capture has up to 15 seconds after the task deadline; the host must allow
time to collect results and clean up. Apply a patch with `git apply` at the
requested commit. Ordinary failures and questions also preserve partial edits.
If patch capture fails, the investigation keeps its findings and questions and
notes the missing patch in its summary.
