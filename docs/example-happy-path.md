# Example: Happy Path

**Scenario:** Add a `delivery_notes` field to the order model so customers can include delivery instructions at checkout.

- Service: `order-service`
- Branch: `mattroberts/sc-11234/add-delivery-notes-field`
- Ticket: SC-11234

---

## The WorkItem (as it appears at end of pipeline)

```markdown
# WorkItem

**Service:** order-service
**Type:** feature
**Date:** 2026-05-15
**Branch:** mattroberts/sc-11234/add-delivery-notes-field
**Base branch:** main
**Shortcut:** https://app.shortcut.com/slice/story/11234

## Spec

### Goal
Allow customers to add free-text delivery instructions (e.g. "leave at door", "call on arrival") when placing an order. Field is optional and stored on the order record.

### Acceptance criteria
- [ ] `delivery_notes` field added to `Order` model, nullable varchar(500)
- [ ] Field included in order creation API payload (optional)
- [ ] Field returned in order detail API response
- [ ] Field stored and retrieved correctly end-to-end
- [ ] Existing orders without the field unaffected

### Files likely touched
- `app/models/order.py`
- `app/schemas/order.py`
- `app/api/orders.py`
- `migrations/versions/xxxx_add_delivery_notes_to_orders.py`

### Known constraints
- Max 500 chars — consistent with other free-text fields in the schema
- Field must be nullable (not all orders have delivery instructions)

### Repo style
- Models: SQLAlchemy declarative base, `app/models/`; nullable fields use `nullable=True, default=None`
- Schemas: Pydantic v2, `app/schemas/`; optional fields use `Optional[str] = None`
- Migrations: Alembic, auto-generated then hand-checked; message format `add_<field>_to_<table>`
- Tests: pytest, integration tests hit a real test DB (no mocking); test files mirror `app/` structure in `tests/`
- Naming: snake_case throughout; model field names match column names

### Out of scope
- UI changes
- Validation beyond length (content filtering etc.)
- Search or filtering by delivery notes

## Implementation

### Branch
mattroberts/sc-11234/add-delivery-notes-field

### Files changed
- `app/models/order.py` — added `delivery_notes` column
- `app/schemas/order.py` — added optional `delivery_notes` field to `OrderCreate` and `OrderResponse`
- `app/api/orders.py` — no changes needed (schema handles it)
- `migrations/versions/20260515_add_delivery_notes_to_orders.py` — Alembic migration

### Baseline
Clean — all 147 tests passing. (Recorded by orchestrator before implement agent was spawned.)

### Key decisions
- Nullable varchar(500) rather than TEXT to enforce the stated constraint at DB level
- No default value (NULL means "not provided", distinct from empty string)
- Schema change is backwards-compatible — field absent from payload treated as None

### Notes for tester
- Migration must run before tests or the column won't exist — `make test` handles this via the test DB fixture
- Edge case: payload with `delivery_notes: ""` (empty string) should be stored as-is, not coerced to None — test this explicitly
- The 500-char limit is enforced by the DB column definition; test that it raises correctly on overflow

### Test focus
1. Empty string vs null distinction — most likely to be subtly wrong
2. 500-char overflow path — ensure it surfaces at schema layer (422), not DB layer

### Issues
None.

### Gate
PASS

## Tests

### Files changed
- `tests/api/test_orders.py`
- `tests/models/test_order.py`

### What's covered
- Order creation with `delivery_notes` present
- Order creation without `delivery_notes` (omitted from payload)
- Order creation with `delivery_notes: ""` (empty string — stored as-is)
- `delivery_notes` returned correctly in order detail response
- `delivery_notes: null` for orders created without the field
- 501-char input raises 422 validation error

### Edge cases verified
- Empty string vs null distinction confirmed
- Overflow raises at schema layer (Pydantic max_length) before hitting DB
- Existing test suite unaffected — all 147 baseline tests still pass

### Run with
`make unit test=tests/api/test_orders.py tests/models/test_order.py`

### Notes for shipper
Clean — no known issues. Migration is additive (nullable column, no backfill needed), safe to run against production with no downtime.

### Issues
None.

### Gate
PASS

## Review

### Outcome
approved

### Notes
Implementation is minimal and correct. Migration is safe. Schema change is backwards-compatible. Test coverage addresses all acceptance criteria including the empty-string edge case called out in handoff notes. No scope creep. No security concerns.

### Gate
PASS

## Ship

### PR URL
https://github.com/slice/order-service/pull/892

### Commit SHA
a3f7c91

### Issues
None.

### Gate
PASS

## Flags

None.
```

---

## Orchestrator narrative

**Step 1 — Load context**

```
Loaded:
  Repo rules:   CLAUDE.md (found), AGENTS.md (found), .claude/CLAUDE.md (not found)
  Feedback:     2 feedback_*.md files from repo memory, 4 from Slice memory
  Repo style:   ### Repo style present in WorkItem
```

**Step 2 — Establish baseline**

Orchestrator runs full suite before spawning implement agent:
```
make test.unit → PASS (147/147)
### Baseline written: Clean — all 147 tests passing.
```

**Step 3 — Spawn implement agent**

Agent completes (lint only, no test suite). Orchestrator runs post-stage verification:
```
Issues:        no unresolved lint failures ✓
make test.unit → PASS (147/147) — no new failures vs baseline ✓
Fields:        Branch ✓  Files changed ✓  Baseline ✓  Key decisions ✓  Notes for tester ✓  Test focus ✓  Gate ✓
No test files in Files changed ✓
```
Gate accepted. Orchestrator commits:
```
feat: add delivery notes field to order model
```

**Step 3 — Spawn test agent**

Agent completes. Orchestrator runs post-stage verification:
```
make unit test=tests/api/test_orders.py tests/models/test_order.py → PASS (6/6)
Fields:     Files changed ✓  What's covered ✓  Edge cases ✓  Run with ✓  Notes for shipper ✓  Gate ✓
```
Gate accepted. Orchestrator commits:
```
test: add delivery notes field to order model
```

**Step 4 — Spawn review agent**

Agent completes. Orchestrator checks consistency:
```
Outcome: approved
Gate:    PASS
Consistent ✓
```

**Step 5 — Spawn ship agent**

Agent reads `### Run with`, runs targeted tests, pushes branch, creates PR. Orchestrator verifies:
```
gh pr view https://github.com/slice/order-service/pull/892   → PR exists ✓
```
Gate accepted.

**Done.** PR URL returned: `https://github.com/slice/order-service/pull/892`

---

## Handover document

```markdown
# Handover: SC-11234 — add delivery notes field to order model

**PR:** https://github.com/slice/order-service/pull/892
**Branch:** mattroberts/sc-11234/add-delivery-notes-field → main
**Commits:** a3f7c91

## What was built

Goal: Allow customers to add free-text delivery instructions when placing an order.

Acceptance criteria:
- [x] `delivery_notes` field added to `Order` model, nullable varchar(500)
- [x] Field included in order creation API payload (optional)
- [x] Field returned in order detail API response
- [x] Field stored and retrieved correctly end-to-end
- [x] Existing orders without the field unaffected

## Issues self-resolved
None.

## Issues raised
None.

## Gate overrides
None.

## Flags
None.

## Review focus areas

1. `migrations/versions/20260515_add_delivery_notes_to_orders.py` — verify the column is nullable with no default, not `server_default=''`. The implementer chose NULL over empty string deliberately.

2. `tests/api/test_orders.py` — the empty-string case (`delivery_notes: ""`) is tested explicitly. Confirm the assertion distinguishes `""` from `null` in the response body.

3. `app/schemas/order.py` — confirm `max_length=500` is on the Pydantic field, not just the DB column. The overflow error should surface as a 422 before hitting the DB.
```
