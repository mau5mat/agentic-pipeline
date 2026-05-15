Look at the current branch, recent commits, and changed files to understand what this PR does. Then fill in the PR template at `.github/PULL_REQUEST_TEMPLATE.md` with accurate, specific content based on the actual changes — do not leave any placeholder text.

Follow these rules:
- Use the Shortcut story ID and URL from the branch name (e.g. `sc-123456` → `SC-123456`) to construct the link at the top: `[**SC-XXXXXX**](https://app.shortcut.com/slicernd/story/XXXXXX/...)`
- For the story URL slug, use the branch name after the story ID
- Write a clear **Issue / Motivation** explaining the bug or feature and why it was broken or needed
- List each meaningful code change in **Changes** — be specific about method names and files
- Do not use em dashes (--) anywhere in the output; use commas, colons, or reword instead
- Write concrete **QA / Acceptance** steps someone could actually follow to verify the fix; remove the feature flag checkbox if there is no flag
- In the **Change Management Checklist**: check Implementation, Risk assessment, Backout, Tests, and Git; uncheck Performance impact and Risk review unless relevant; remove the Migrations line if there are no migrations
- Set risk to Low/Medium/High with a brief justification
- Backout should always say "To backout the changes, create a revert PR targeting master"
- Remove the Migrations checklist item

Once complete, write the filled-in description as a markdown file to `<repo-root>/.handovers/` named `<service-name>-<story_id>.md` (e.g. `.handovers/ros-service-sc-654433.md`), where `<repo-root>` is `$(git rev-parse --show-toplevel)` and the service name is derived from the repository directory name. Create the directory with `mkdir -p` first. Then print the contents so the user can review it.
