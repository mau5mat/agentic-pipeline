# Pipeline Abort and Recovery

What to do when a pipeline run needs to be stopped or unwound at each stage.

---

## General principle

The WorkItem is the source of truth for pipeline state. A stage is only considered complete when its `### Gate` field is explicitly `PASS`. Any other state (partial content, `FAIL`, missing gate) means the stage is incomplete and the pipeline will resume from there on the next `/pipeline` run.

---

## Stopping cleanly at any stage

Just halt — the WorkItem preserves state. When you re-run `/pipeline`, it reads the gate fields and resumes from the first incomplete stage. You do not need to clean up the WorkItem manually.

---

## Undoing a stage

### After implement (code written, not yet committed)
```bash
git checkout -- .        # discard all unstaged changes
git clean -fd            # remove untracked files (new files from implementation)
```
Then clear the Implementation section in the WorkItem back to `> To be filled by pipeline-implement.` and re-run `/pipeline`.

### After implement (committed, not yet pushed)
```bash
git reset HEAD~1         # undo the commit, keep changes staged
git reset HEAD -- .      # unstage everything
git checkout -- .        # discard changes
git clean -fd
```
Then clear the Implementation section and re-run.

### After test (committed, not yet pushed)
```bash
git reset HEAD~1         # undo the test commit
git reset HEAD -- .
git checkout -- .
git clean -fd
```
Clear the Tests section in the WorkItem and re-run from test stage.

### After push (branch pushed, no PR yet)
The branch is on remote. If you want to remove it:
```bash
git push origin --delete <branch-name>
```
Then reset locally as above. Re-push when ready.

### After PR created
Do not delete the PR programmatically — close it manually in GitHub if needed. The branch can stay until you're ready to re-push.

---

## Fixing a gate failure without restarting

If a stage wrote `Gate: FAIL` and you've fixed the issue manually:

1. Clear only the gate line — change `### Gate\nFAIL: <reason>` back to the stage's `> To be filled` placeholder, or just delete the gate line.
2. Re-run `/pipeline` — it will re-enter the failed stage.

You do not need to clear the whole section unless the content is wrong.

---

## WorkItem got corrupted or is in a bad state

The WorkItem is a plain markdown file at `~/Development/Slice/workitems/<service>/workitem-<sc>.md`. Edit it directly to fix any state issue — the pipeline reads it fresh each time.

If you're unsure what state a run left things in:
```bash
git log --oneline          # see what commits the pipeline made
git status                 # see what's staged or unstaged
cat <WORKITEM path>        # read the current gate states
```
