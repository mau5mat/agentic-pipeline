You are the **pipeline demo agent**. Run a simulated pipeline to demonstrate how the agentic development pipeline looks in practice. You write directly to the WorkItem at each stage — no sub-agents are spawned. No source files are modified.

## Arguments

`/pipeline-demo [--fail-at implement|test|review]`

- `--fail-at implement` — simulates a lint failure; shows the FAIL gate and Retry/Override/Halt flow
- `--fail-at test` — simulates a test failure mid-suite
- `--fail-at review` — simulates the review agent catching an unmet acceptance criterion
- No argument — clean run, all stages pass

## Step 1: Parse and confirm

```bash
source "$HOME/.claude/pipeline.conf" 2>/dev/null || true

REPO=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$REPO" ] && { echo "Error: not in a git repository."; exit 1; }

SERVICE=$(basename "$REPO")
DEMO_SC="sc-000001"
DEMO_SC_NUM="000001"
DEMO_BRANCH="demo/sc-000001/-add-request-id-logging"
WORKITEM="$REPO/.workitems/workitem-${DEMO_SC}.md"
HANDOVER="$REPO/.handovers/handover-${DEMO_SC}.md"
ORIGINAL_BRANCH=$(git branch --show-current)
```

Parse `--fail-at` from the argument. Set `FAIL_AT` to `implement`, `test`, `review`, or empty string.

If a WorkItem already exists at `$WORKITEM`, stop:
> "Demo WorkItem already exists at `$WORKITEM`. Remove it first: `rm $WORKITEM`"

Output exactly this, substituting values:
```
Pipeline demo
  Scenario:  Add request ID to log output
  Repo:      <SERVICE>
  Branch:    <DEMO_BRANCH>
  Fail at:   <FAIL_AT or 'none — clean run'>

Type 'go' to start or anything else to cancel.
```

Wait for user input. If not 'go', stop.

## Step 2: Setup

```bash
git checkout -b "$DEMO_BRANCH" 2>/dev/null || git checkout "$DEMO_BRANCH"

mkdir -p "$REPO/.pipeline-state/$DEMO_SC_NUM"
mkdir -p "$REPO/.workitems"
mkdir -p "$REPO/.handovers"

# Cleanup trap — runs on exit so an interrupted demo doesn't leave state behind
trap 'rm -rf "$REPO/.pipeline-state/$DEMO_SC_NUM"; git checkout "$ORIGINAL_BRANCH" 2>/dev/null || true' EXIT

printf '{"sc":"%s","stage":"orchestrating","stage_num":0,"start_time":%d,"status":"running"}' "$DEMO_SC" "$(date +%s)" > "$REPO/.pipeline-state/$DEMO_SC_NUM/pipeline-state.json"
```

## Step 3: Write WorkItem (simulates /pipeline-plan output)

Output: `[plan] Writing WorkItem...`

Write to `$WORKITEM` (substitute `<SERVICE>` and `<DATE>`):

```markdown
# Work Item: SC-000001 — Add request ID to log output

**Service:** <SERVICE>
**Type:** feature
**Date:** <DATE>
**Branch:** demo/sc-000001/-add-request-id-logging

## Flags
> Any stage may append here. Reviewed by human before ship.

---

## Spec
> Set during planning. Read-only for all downstream stages.

### Goal
Add a unique request ID to all log output so that logs from a single request can be
correlated across concurrent traffic. Currently logs from concurrent requests are
interleaved with no way to trace which lines belong to which request.

### Acceptance criteria
- [ ] Each incoming request is assigned a unique ID (UUID v4)
- [ ] The request ID appears in all log lines emitted during that request
- [ ] The request ID is returned to the caller as an X-Request-ID response header
- [ ] Existing log format is preserved — request ID is added as a structured field

### Files likely touched
- `app/middleware/request_id.py` — new middleware class
- `app/main.py` — register middleware on app startup
- `app/logging.py` — inject request ID from context into log records
- `tests/test_request_id.py` — new test file

### Known constraints / gotchas
- Must use `contextvars.ContextVar` for propagation, not thread-local storage — the
  service uses async request handlers
- Do not trust an incoming X-Request-ID header as authoritative — always generate a
  new ID server-side. Log both if the header is present (useful for cross-service tracing)
- The logging patch must not break existing tests that run without a request context

### Known broken tests
None.

### Repo style
**Code style:** snake_case, explicit returns, type hints on public functions, class-based
middleware following existing patterns.

**Test style:** pytest, fixtures in conftest.py, assertions on response body and headers
via TestClient, caplog for log assertions.

**Paradigms:** Async-first, layered (routes → services → repos).

**Make targets:**
- Lint: `make lint`
- Full suite: `make test`
- Targeted: `make test target=tests/test_request_id.py`

### Out of scope
- Propagating request IDs to outbound HTTP calls (follow-on)
- Persistent request ID storage or indexing

### Planning timing
4m

---

## Implementation
> To be filled by pipeline-implement.

---

## Tests
> To be filled by pipeline-test.

---

## Review
> To be filled by pipeline-review.

---

## Ship
> To be filled by pipeline-ship.
```

Update pipeline state and sleep 3 seconds:
```bash
printf '{"sc":"%s","stage":"orchestrating","stage_num":0,"start_time":%d,"status":"running"}' "$DEMO_SC" "$(date +%s)" > "$REPO/.pipeline-state/$DEMO_SC_NUM/pipeline-state.json"
sleep 3
```

Output: `WorkItem written. Starting pipeline...`

---

## Step 4: Simulate stages

### Stage: Implement

```bash
printf '{"sc":"%s","stage":"implement","stage_num":1,"start_time":%d,"status":"running"}' "$DEMO_SC" "$(date +%s)" > "$REPO/.pipeline-state/$DEMO_SC_NUM/pipeline-state.json"
```

Output: `[implement] Running...`

Sleep 10 seconds.

**If `FAIL_AT == implement`**, append to `$WORKITEM`:

```markdown
## Implementation

### Changes made
- Created `app/middleware/request_id.py` — `RequestIDMiddleware` generates UUID v4 per
  request, sets context var, attaches X-Request-ID to response
- Modified `app/logging.py` — `RequestIDFilter` reads from context var, adds `request_id`
  field to every log record
- Modified `app/main.py` — registered middleware on app startup

### Decisions made
- Used `uuid.uuid4()` — UUID is more universally recognised in log aggregators than hex tokens
- Middleware attaches ID to response before handler runs, so it is present even on
  early-exit responses (e.g. 422 validation errors)

### Lint result
```
app/middleware/request_id.py:3: F401 'uuid.UUID' imported but unused
1 error
```

### Gate
FAIL [code]: lint — unused import at app/middleware/request_id.py:3
```

Then output:
```
[implement] Gate: FAIL [code]

  lint — unused import at app/middleware/request_id.py:3

  Options:
    1. Retry     — fix the issue and re-run the implement stage
    2. Override  — record the failure and continue anyway
    3. Halt      — stop the pipeline

Choice [1/2/3]:
```

Wait for user input:
- If `1` (Retry): output `[implement] Retrying...`, sleep 6, replace the `FAIL [code]: lint...` line in the `### Gate` block with `PASS`, and continue.
- If `2` (Override): append to the Flags section: `[orchestrator] Gate override at implement: unused import in request_id.py:3 — user chose to proceed.` and continue.
- If `3` (Halt): run Step 6 cleanup and stop.

**If `FAIL_AT != implement`**, append to `$WORKITEM`:

```markdown
## Implementation

### Changes made
- Created `app/middleware/request_id.py` — `RequestIDMiddleware` generates UUID v4 per
  request, sets `request_id_ctx` context var, attaches X-Request-ID to response
- Modified `app/logging.py` — `RequestIDFilter` reads from `request_id_ctx`, adds
  `request_id` field to every log record. Falls back to "-" when no context is set
- Modified `app/main.py` — registered `RequestIDMiddleware` before other middleware

### Decisions made
- Used `uuid.uuid4()` — UUID more universally recognised in log aggregators than hex tokens
- Middleware attaches ID before handler runs so it is present on early-exit responses
- `RequestIDFilter` fails silently when context var is unset rather than raising, to
  preserve existing log behaviour for non-request contexts (startup, background tasks)

### Timing
14m

### Gate
PASS
```

```bash
printf '{"sc":"%s","stage":"verifying","stage_num":1,"start_time":%d,"status":"running"}' "$DEMO_SC" "$(date +%s)" > "$REPO/.pipeline-state/$DEMO_SC_NUM/pipeline-state.json"
sleep 3
printf '{"sc":"%s","stage":"orchestrating","stage_num":1,"start_time":%d,"status":"running"}' "$DEMO_SC" "$(date +%s)" > "$REPO/.pipeline-state/$DEMO_SC_NUM/pipeline-state.json"
sleep 2
```

---

### Stage: Test

```bash
printf '{"sc":"%s","stage":"test","stage_num":2,"start_time":%d,"status":"running"}' "$DEMO_SC" "$(date +%s)" > "$REPO/.pipeline-state/$DEMO_SC_NUM/pipeline-state.json"
```

Output: `[test] Running...`

Sleep 10 seconds.

**If `FAIL_AT == test`**, append to `$WORKITEM`:

```markdown
## Tests

### Tests written
- `tests/test_request_id.py` — 4 tests covering: ID generated per request, ID in logs,
  header set on response, no crash when context is absent

### Test decisions
- Tested at the HTTP boundary via TestClient rather than unit-testing the middleware
  class directly
- Used caplog fixture to assert request ID appears in log records

### Test results
```
FAILED tests/test_request_id.py::test_concurrent_requests_get_different_ids
AssertionError: expected 2 unique IDs, got 1
context var not properly isolated between requests in test harness
```

### Gate
FAIL [code]: test_concurrent_requests_get_different_ids — context var isolation issue in test setup
```

Then present Retry/Override/Halt as above with the relevant failure message.

**If `FAIL_AT != test`**, append to `$WORKITEM`:

```markdown
## Tests

### Tests written
- `tests/test_request_id.py` — 5 tests

### Test decisions
- Tested at HTTP boundary via TestClient — header presence, log output via caplog,
  concurrent request isolation
- Avoided mocking uuid4 directly; asserted uniqueness across two requests instead
- Added a no-context test (simulates startup log) to confirm the "-" fallback does not raise

### Timing
11m

### Gate
PASS
```

```bash
printf '{"sc":"%s","stage":"verifying","stage_num":2,"start_time":%d,"status":"running"}' "$DEMO_SC" "$(date +%s)" > "$REPO/.pipeline-state/$DEMO_SC_NUM/pipeline-state.json"
sleep 3
printf '{"sc":"%s","stage":"orchestrating","stage_num":2,"start_time":%d,"status":"running"}' "$DEMO_SC" "$(date +%s)" > "$REPO/.pipeline-state/$DEMO_SC_NUM/pipeline-state.json"
sleep 2
```

---

### Stage: Review

```bash
printf '{"sc":"%s","stage":"review","stage_num":3,"start_time":%d,"status":"running"}' "$DEMO_SC" "$(date +%s)" > "$REPO/.pipeline-state/$DEMO_SC_NUM/pipeline-state.json"
```

Output: `[review] Running...`

Sleep 8 seconds.

**If `FAIL_AT == review`**, append to `$WORKITEM`:

```markdown
## Review

### Criteria check
- [x] Each incoming request is assigned a unique ID (UUID v4) — confirmed in middleware
- [x] The request ID appears in all log lines — confirmed via RequestIDFilter and test
- [ ] The request ID is returned as X-Request-ID response header — **FAIL**: middleware
      sets the header on the Starlette request object but does not attach it to the
      Response. Header is absent in actual HTTP responses. test_response_header passes
      because it reads from request state rather than the response headers directly —
      the test has a false positive.
- [x] Existing log format preserved — no regressions in existing log tests

### Gate
FAIL [code]: acceptance criterion not met — X-Request-ID not present in HTTP response (middleware sets it on request object, not response; test has false positive)
```

Then present Retry/Override/Halt.

**If `FAIL_AT != review`**, append to `$WORKITEM`:

```markdown
## Review

### Criteria check
- [x] Each incoming request is assigned a unique ID (UUID v4) — confirmed in middleware
- [x] The request ID appears in all log lines — confirmed via RequestIDFilter and test_request_id_in_logs
- [x] The request ID is returned as X-Request-ID response header — confirmed in test_response_header
- [x] Existing log format preserved — no regressions, startup log fallback tested

### Notes
- Tests are meaningful and test observable HTTP behaviour, not implementation internals
- No scope creep observed
- Non-blocking: RequestIDFilter is registered globally rather than per-handler, which is
  correct but worth a short comment for future readers

### Timing
8m

### Gate
PASS
```

```bash
printf '{"sc":"%s","stage":"verifying","stage_num":3,"start_time":%d,"status":"running"}' "$DEMO_SC" "$(date +%s)" > "$REPO/.pipeline-state/$DEMO_SC_NUM/pipeline-state.json"
sleep 3
printf '{"sc":"%s","stage":"orchestrating","stage_num":3,"start_time":%d,"status":"running"}' "$DEMO_SC" "$(date +%s)" > "$REPO/.pipeline-state/$DEMO_SC_NUM/pipeline-state.json"
sleep 2
```

---

### Stage: Ship

```bash
printf '{"sc":"%s","stage":"ship","stage_num":4,"start_time":%d,"status":"running"}' "$DEMO_SC" "$(date +%s)" > "$REPO/.pipeline-state/$DEMO_SC_NUM/pipeline-state.json"
```

Output: `[ship] Running...`

Sleep 5 seconds.

Append to `$WORKITEM` (substitute `<SERVICE>`):

```markdown
## Ship

### PR
https://github.com/your-org/<SERVICE>/pull/42  (simulated)

### Commit
feat: add request ID middleware for log correlation

### Timing
3m

### Gate
PASS
```

---

## Step 5: Write handover doc

```bash
printf '{"sc":"%s","stage":"orchestrating","stage_num":4,"start_time":%d,"status":"running"}' "$DEMO_SC" "$(date +%s)" > "$REPO/.pipeline-state/$DEMO_SC_NUM/pipeline-state.json"
```

Write to `$HANDOVER` (substitute `<SERVICE>` and `<DATE>`):

```markdown
# Handover: SC-000001 — Add request ID to log output

**Service:** <SERVICE>
**Branch:** demo/sc-000001/-add-request-id-logging
**PR:** https://github.com/your-org/<SERVICE>/pull/42 (simulated)
**Date:** <DATE>

---

## What was built

Request ID middleware that assigns a UUID v4 to each incoming request, propagates it
via contextvars, injects it into all log output via a logging filter, and returns it
as an X-Request-ID response header.

## Issues encountered

None. All stages passed on first attempt.

## Flags

None.

## Timing

| Stage | Duration |
|-------|----------|
| Planning | 4m |
| Implement | 14m |
| Test | 11m |
| Review | 8m |
| Ship | 3m |
| **Pipeline total** | **40m** |

## QA checklist

Deploy the branch and verify each item manually:

- [ ] Send a request and confirm X-Request-ID is present in the response headers
- [ ] Tail logs during a request — confirm `request_id` field appears on every log line
      emitted during that request
- [ ] Send two concurrent requests and confirm they receive different IDs in both logs
      and response headers
- [ ] Check startup logs (before first request) — `request_id` field should show "-"
- [ ] Confirm existing log format is unchanged for non-request contexts
```

---

## Step 6: Cleanup and output

```bash
rm -rf "$REPO/.pipeline-state/$DEMO_SC_NUM"
git checkout "$ORIGINAL_BRANCH"
```

Output (substitute values):
```
Demo complete.

PR:       https://github.com/your-org/<SERVICE>/pull/42  (simulated)
Handover: <HANDOVER>
WorkItem: <WORKITEM>

Clean up? [Y/n]:
```

Wait for user input. If Y or empty (default yes):
```bash
rm -f "$WORKITEM" "$HANDOVER"
git branch -d "$DEMO_BRANCH" 2>/dev/null || true
```
Output: `Cleaned up. Nothing left behind.`

If N:
Output:
```
Artifacts left in place. To clean up manually:
  rm <WORKITEM> <HANDOVER>
  git branch -d demo/sc-000001/-add-request-id-logging
```

---

## Note: using the demo to verify your setup

If the demo completes successfully, your pipeline installation is working correctly:
git is present, the pipeline config was sourced, the status bar updated throughout, and
the WorkItem and handover doc were written to the right places. A successful demo run
is a reasonable smoke test before running the real pipeline for the first time.
