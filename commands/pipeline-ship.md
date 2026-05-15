You are the **ship agent** in the development pipeline. Run final checks, push the branch, create the PR, and update the WorkItem.

## Locate the WorkItem

```bash
REPO=$(git rev-parse --show-toplevel)
BRANCH=$(git branch --show-current)
SC=$(echo "$BRANCH" | grep -oiE 'sc-[0-9]+' | head -1)
WORKITEM="$REPO/.workitems/workitem-${SC}.md"
```

Read the full WorkItem before doing anything. Pay close attention to **Tests → Notes for shipper** — it contains anything from the test agent you should know before pushing. Check the **Flags** section first — if anything is flagged as blocking, stop and report to the user before proceeding. Note the **Base branch** field from the WorkItem header — this is the target for the PR.

## Steps

1. Run final checks. Both must pass. Do not push if either fails:
   - Lint — use the lint command from `### Repo style`
   - Read the `### Run with` field from the Tests section of the WorkItem — it contains the exact targeted test command. Run that command. The full suite was already verified by the orchestrator after the implement stage; do not re-run it.

2. Generate the PR description by reading and following the instructions in `~/.claude/commands/pr-description.md` exactly. Those instructions are authoritative — do not substitute your own rules.

3. Push the branch:
   ```bash
   git push -u origin <branch-name>
   ```

4. Create the PR with a title in conventional commits format — same type mapping as the implement commit (feature → feat, bug → fix, migration → chore), description from the WorkItem Goal:
   ```bash
   gh pr create --title "feat|fix|chore: <short description from Goal>" --base <base-branch-from-WorkItem> --body "$(cat <pr-description-file>)"
   ```

5. Append to the **Ship** section of the WorkItem:

```
## Ship

### PR URL
[url from gh pr create output]

### Commit SHA
[git rev-parse HEAD]

### Issues
[populated during triage — see below]
```

## Triage and gate

**Checks:**
- Lint passes (command from `### Repo style`)
- Targeted tests pass (command from `### Run with`)
- `git push` succeeded
- PR created and URL captured

**Classification:**

Self-resolve:
- Lint errors → fix them (max 2 retries)

Raise immediately:
- Test failures (should have been caught earlier — something regressed)
- Push failure (permissions, conflicts, network)
- PR creation failure

**Log every issue in `### Issues`**.

**Gate result** (write as final action):
- All checks pass → `### Gate\nPASS`
- Lint unresolved, test failures → `### Gate\nFAIL [code]: <reason>`
- Push failure, PR creation failure → `### Gate\nFAIL [env]: <reason>`

Report: "PR created: [url]. Gate: PASS." (or "Gate: FAIL [type]: <reason>")
