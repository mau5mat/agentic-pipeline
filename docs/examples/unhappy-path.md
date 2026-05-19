# Example: Unhappy Path

**Scenario:** Add a webhook endpoint that fires when a payment retry is scheduled, so downstream services can react.

The unhappy path demonstrates:
- Pre-existing test failures saved to Baseline (excluded, not raised)
- Lint errors self-resolved by the implement agent
- A missing edge case self-resolved by the test agent
- Review raising a security concern, Gate: FAIL, user retries implement stage
- Clean ship after retry

- Service: `payment-service`
- Branch: `username/sc-11456/add-payment-retry-webhook`
- Ticket: SC-11456

---

## The WorkItem (as it appears at end of pipeline)

```markdown
# Work Item SC-11456: add payment retry webhook

**Service:** payment-service
**Type:** feature
**Date:** 2026-05-15
**Branch:** username/sc-11456/add-payment-retry-webhook
**Base branch:** main
**Shortcut:** https://app.shortcut.com/your-org/story/11456

## Flags
> Any stage may append here. Reviewed by human before ship.

[reviewer] Security (first review pass): `webhook_dispatcher.py` was sending requests without a signature when `WEBHOOK_SIGNING_KEY` was absent from the environment (silent failure: no exception, just no header). This allows unsigned webhooks to reach subscribers with no indication they are unverified. AC explicitly requires HMAC signing. Gate: FAIL.

[orchestrator] Gate: FAIL at review (security: unsigned webhook delivery on missing signing key). User chose Retry. Implement and test stages re-run. Review approved on second pass.

---

## Spec
> Set during planning. Read-only for all downstream stages.

### Goal
Fire a webhook to registered subscribers when a payment retry is scheduled. Subscribers receive the order ID, retry count, and next retry timestamp.

### Acceptance criteria
- [ ] `POST /webhooks/payment-retry` endpoint accepts and stores subscriber URLs
- [ ] Webhook fires on `payment.retry_scheduled` event with payload: `{order_id, retry_count, next_retry_at}`
- [ ] Webhook requests include HMAC-SHA256 signature header for subscriber verification
- [ ] Failed webhook deliveries are logged (no retry mechanism in scope)
- [ ] Endpoint requires API key authentication

### Files likely touched
- `app/api/webhooks.py`
- `app/services/webhook_dispatcher.py`
- `app/models/webhook_subscription.py`
- `app/events/payment_events.py`
- `tests/api/test_webhooks.py`
- `tests/services/test_webhook_dispatcher.py`

### Known constraints / gotchas
- HMAC key is in environment config (`WEBHOOK_SIGNING_KEY`)
- Delivery must be async (Celery task): do not block the payment retry flow

### Known broken tests
None.

### Repo style
- API: FastAPI, routers in `app/api/`; auth via `Depends(require_api_key)`
- Services: plain classes, injected via FastAPI `Depends`
- Events: dataclasses in `app/events/`; dispatched via `event_bus.emit()`
- Tests: pytest + httpx TestClient; real DB, Celery tasks run eagerly in test mode (`CELERY_TASK_ALWAYS_EAGER=true`)
- Async tasks: Celery, tasks in `app/tasks/`

**Make targets:**
- Lint: `make lint`
- Full suite: `make test.unit`
- Targeted: `make unit test=<space-separated paths>`

### Out of scope
- Webhook retry logic
- Subscriber management UI
- Webhook delivery history API

### Planning timing
6m

---

## Implementation
> Branch, Files changed, Key decisions, Notes for tester, Test focus, Issues, and Gate are filled by pipeline-implement. Baseline is written by the orchestrator before the implement agent is spawned.

### Branch
username/sc-11456/add-payment-retry-webhook

### Files changed
- `app/api/webhooks.py`: subscription registration endpoint
- `app/services/webhook_dispatcher.py`: HMAC signing + HTTP delivery
- `app/tasks/webhook_tasks.py`: Celery task wrapping dispatcher
- `app/models/webhook_subscription.py`: WebhookSubscription model
- `app/events/payment_events.py`: wired `payment.retry_scheduled` to task
- `migrations/versions/20260515_add_webhook_subscriptions.py`: new table

### Baseline
2 pre-existing failures recorded:
- `tests/tasks/test_payment_tasks.py::test_retry_backoff_jitter`: known flaky, tracked in SC-11089
- `tests/integration/test_payment_flow.py::test_3ds_timeout`: environment issue in CI, passes locally

### Key decisions
- Signing key read from `settings.WEBHOOK_SIGNING_KEY` at dispatch time (not cached) so key rotation takes effect immediately
- Subscriber URLs stored in DB rather than config: allows runtime registration without redeploy
- Delivery task is fire-and-forget; failures logged via structlog, not raised

### Notes for tester
- Test HMAC header: `X-Webhook-Signature: sha256=<hex>`; compute expected value with `hmac.new(key, payload, sha256).hexdigest()`
- Test the case where `WEBHOOK_SIGNING_KEY` is missing from env: dispatcher should raise `ImproperlyConfigured`, not silently send unsigned requests
- Celery runs eagerly in test mode so webhook delivery is synchronous in tests

### Test focus
1. Missing signing key behaviour: most likely to be subtly wrong (silent no-op vs explicit raise)
2. HMAC header value correctness: not just presence, but correct computation
3. Baseline exclusions: `test_retry_backoff_jitter`, `test_3ds_timeout`: do not raise these

### Issues
- [self-resolved] Lint: unused import `datetime` in `app/services/webhook_dispatcher.py`: removed
- [self-resolved] Lint: line too long in `app/tasks/webhook_tasks.py:34`: reformatted

### Timing
20m + 8m

### Gate
PASS

---

## Tests
> To be filled by pipeline-test.

### Files changed
- `tests/api/test_webhooks.py`
- `tests/services/test_webhook_dispatcher.py`

### What's covered
- Subscriber registration: success, duplicate URL, invalid URL
- Webhook fires on `payment.retry_scheduled` with correct payload shape
- HMAC signature header present and correct
- Missing `WEBHOOK_SIGNING_KEY` raises `ImproperlyConfigured`
- Failed delivery logged (mock HTTP 500 from subscriber)
- Endpoint rejects unauthenticated requests (no API key)
- Baseline failures excluded: `test_retry_backoff_jitter`, `test_3ds_timeout`

### Edge cases verified
- Empty subscriber list: no tasks dispatched, no error
- Subscriber URL returns HTTP 500: logged, not raised, task returns successfully
- Payload serialisation: `next_retry_at` is ISO 8601 string (not epoch int)

### Run with
`make unit test=tests/api/test_webhooks.py tests/services/test_webhook_dispatcher.py`

### Notes for shipper
`WEBHOOK_SIGNING_KEY` must be set in the environment before deploy: dispatcher raises `ImproperlyConfigured` on first webhook fire if missing. Confirm it's in the secrets manager before merging.

### Issues
- [self-resolved] Missing coverage: `payload serialisation: next_retry_at format` not in original test plan; added `test_webhook_payload_timestamp_format`

### Timing
11m + 4m

### Gate
PASS

---

## Review
> To be filled by pipeline-review.

### Outcome
approved

### Notes
Second review pass (first returned Gate: FAIL; see Flags). Security concern resolved: `ImproperlyConfigured` is now raised on missing signing key rather than sending unsigned requests. Verified the fix is tested. All acceptance criteria met. Test coverage is thorough. No scope creep.

### Timing
8m + 5m

### Gate
PASS

---

## Ship
> To be filled by pipeline-ship.

### PR URL
https://github.com/your-org/payment-service/pull/441

### Commit SHA
d9e2b47

### Issues
None.

### Timing
3m

### Gate
PASS
```

---

## Orchestrator narrative

**Step 1: Load context**

```
Loaded:
  Repo rules:   CLAUDE.md (found), AGENTS.md (found), .claude/CLAUDE.md (not found)
  Feedback:     1 feedback_*.md file from repo memory, 4 from org memory
  Repo style:   ### Repo style present in WorkItem
```

**Step 2: Establish baseline**

Orchestrator runs full suite before spawning implement agent:
```
make test.unit → 2 failures
  FAILED tests/tasks/test_payment_tasks.py::test_retry_backoff_jitter
  FAILED tests/integration/test_payment_flow.py::test_3ds_timeout
### Baseline written: 2 pre-existing failures recorded (see ### Baseline in WorkItem)
```

**Step 3: Spawn implement agent (first pass)**

Agent self-resolves 2 lint errors. Appends `### Gate\nPASS`.

Orchestrator runs post-stage verification:
```
Issues:        no unresolved lint failures ✓
make test.unit → PASS (excluding 2 baseline failures) ✓
Fields:        Branch ✓  Files changed ✓  Baseline ✓  Key decisions ✓  Notes for tester ✓  Test focus ✓  Timing ✓  Gate ✓
No test files in Files changed ✓
```
Gate accepted. Orchestrator commits:
```
feat: add payment retry webhook
```

**Step 4: Spawn test agent (first pass)**

Agent self-resolves one missing edge case (timestamp format). Appends `### Gate\nPASS`.

Orchestrator runs post-stage verification:
```
make unit test=tests/api/test_webhooks.py tests/services/test_webhook_dispatcher.py → PASS
Fields:     Files changed ✓  What's covered ✓  Edge cases ✓  Run with ✓  Notes for shipper ✓  Timing ✓  Gate ✓
```
Gate accepted. Orchestrator commits:
```
test: add payment retry webhook
```

**Step 5: Spawn review agent (first pass)**

Agent finds security concern: unsigned webhook delivery when signing key is absent. Appends to Flags with `[reviewer]` prefix. Writes `### Gate\nFAIL: missing signing key sends unsigned webhooks; AC requires HMAC on all deliveries`.

Orchestrator reads Gate: FAIL. Presents to user:

```
Gate: FAIL at review
Reason: missing signing key sends unsigned webhooks; AC requires HMAC on all deliveries

Options:
  [R] Retry: fix the issue and re-run from implement
  [O] Override: proceed anyway (recorded in Flags)
  [H] Halt: stop the pipeline
```

User selects **Retry**.

**Step 3 (retry): Spawn implement agent**

Retry detection: `feat: add payment retry webhook` already exists on branch.

Agent fixes `webhook_dispatcher.py` to raise `ImproperlyConfigured` on missing key. Appends `### Gate\nPASS`.

Orchestrator records retry in Flags: `[orchestrator] Gate: FAIL at review. User chose Retry.`

Post-stage verification:
```
Issues:        no unresolved lint failures ✓
make test.unit → PASS (excluding 2 baseline failures) ✓
Fields:        ✓
No test files in Files changed ✓
```
Gate accepted. Orchestrator commits:
```
fix: raise ImproperlyConfigured on missing WEBHOOK_SIGNING_KEY
```

**Step 4 (retry): Spawn test agent**

Retry detection: `test: add payment retry webhook` already exists on branch.

Agent verifies fix is covered (`test_missing_signing_key_raises` already present from first pass: no new tests needed). Appends `### Gate\nPASS`.

Post-stage verification:
```
make unit test=tests/api/test_webhooks.py tests/services/test_webhook_dispatcher.py → PASS
Fields:     ✓
```
Gate accepted. Orchestrator commits:
```
fix: confirm ImproperlyConfigured coverage in tests
```

**Step 5 (retry): Spawn review agent (second pass)**

Agent approves. Appends `### Gate\nPASS`.

Orchestrator checks consistency:
```
Outcome: approved
Gate:    PASS
Consistent ✓
```

**Step 6: Spawn ship agent**

Agent reads `### Notes for shipper`: notes `WEBHOOK_SIGNING_KEY` must be in secrets before deploy. Pushes branch, creates PR.

Orchestrator verifies:
```
gh pr view https://github.com/your-org/payment-service/pull/441   → PR exists ✓
```
Gate accepted.

**Done.** PR URL returned: `https://github.com/your-org/payment-service/pull/441`

---

## Handover document

```markdown
# Handover: SC-11456, add payment retry webhook

**PR:** https://github.com/your-org/payment-service/pull/441
**Branch:** username/sc-11456/add-payment-retry-webhook → main
**Commits:** feat: add payment retry webhook → test: add payment retry webhook → fix: raise ImproperlyConfigured on missing WEBHOOK_SIGNING_KEY → fix: confirm ImproperlyConfigured coverage in tests

## What was built

Goal: Fire a webhook to registered subscribers when a payment retry is scheduled.

Acceptance criteria:
- [x] `POST /webhooks/payment-retry` endpoint accepts and stores subscriber URLs
- [x] Webhook fires on `payment.retry_scheduled` with payload: `{order_id, retry_count, next_retry_at}`
- [x] Webhook requests include HMAC-SHA256 signature header for subscriber verification
- [x] Failed webhook deliveries are logged (no retry mechanism in scope)
- [x] Endpoint requires API key authentication

## Issues self-resolved

- [implement] Lint: unused import `datetime` in `app/services/webhook_dispatcher.py`: removed
- [implement] Lint: line too long in `app/tasks/webhook_tasks.py:34`: reformatted
- [test] Missing coverage: `next_retry_at` timestamp format: added `test_webhook_payload_timestamp_format`

## Issues raised

- [review] Security: `webhook_dispatcher.py` was sending requests without a signature when `WEBHOOK_SIGNING_KEY` was absent: silent unsigned delivery. Gate: FAIL.
  **Decision:** User chose Retry. Implement fix: dispatcher now raises `ImproperlyConfigured` on missing key. Confirmed covered in tests. Review approved on second pass.

## Gate overrides

None. Review Gate: FAIL triggered a user Retry (not Override). See Issues raised.

## Flags

- `WEBHOOK_SIGNING_KEY` must be set in secrets manager before deploy: dispatcher raises on first webhook fire if missing. Confirm before merging.

## Review focus areas

1. `app/services/webhook_dispatcher.py`: the key fix from the retry: verify `ImproperlyConfigured` is raised on `None`/missing key, not just on empty string. The original bug was a silent no-op.

2. `app/tasks/webhook_tasks.py`: confirm the Celery task catches dispatcher exceptions correctly. A raised `ImproperlyConfigured` should surface to the task runner, not be swallowed.

3. `tests/services/test_webhook_dispatcher.py::test_missing_signing_key_raises`: the test that validates the fix. Make sure it asserts on the exception type, not just that an exception is raised.

4. `app/api/webhooks.py`: subscriber registration accepts arbitrary URLs. Confirm there's no SSRF risk: internal IPs or `localhost` URLs should not be registerable. (Noted as out-of-scope for this ticket but worth flagging for a follow-up.)
```
