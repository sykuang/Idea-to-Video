# Video project state

`VIDEO_PROJECT.json` is the source of truth for workflow position. It contains no credentials.

## Required shape

```json
{
  "schema_version": 1,
  "project_id": "project-slug",
  "title": "Human-readable title",
  "project_root": "absolute path",
  "current_stage": "START",
  "stage_status": "in_progress",
  "pending_request": "The one current user decision",
  "next_stage": "IDEA_GRILL",
  "decisions": {},
  "artifacts": {},
  "shots": {},
  "stage_history": [],
  "created_at": "ISO-8601 timestamp",
  "updated_at": "ISO-8601 timestamp"
}
```

Allowed stages:

`START`, `IDEA_GRILL`, `BRIEF`, `PRODUCTION_PLAN`, `PROMPT_PILOT`, `PILOT_RENDER`, `SHOT_RENDER`, `REVIEW`, `ASSEMBLY`, `FINAL_ACCEPTANCE`.

Allowed statuses:

`not_started`, `in_progress`, `awaiting_approval`, `approved`, `needs_revision`, `skipped`.

## Rules

1. Update state after a material artifact, approval, rejection, render attempt, or stage transition.
2. `pending_request` contains one current action, not a future checklist.
3. Each decision records `value`, `source`, and `status`.
4. Each shot records dependencies, current approved attempt, and all prior attempt paths.
5. Artifact paths are absolute in state, but user-facing public documents do not expose private paths.
6. Never store tokens, cookies, login URLs, device codes, or secrets.
7. When returning to an earlier stage, keep downstream artifacts and mark them `stale: true`.
8. On resume, verify the latest approved artifact exists before continuing.
