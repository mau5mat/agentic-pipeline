# Roadmap

## Future ideas

### Parallel worktree orchestration
After the implement stage completes, if the WorkItem has independent sub-tasks identified during the parallelism check, offer to spawn parallel worktree sessions for them rather than continuing sequentially.

### Pipeline for Track A work
The current pipeline assumes one person working one story. A future version could orchestrate multi-track work with explicit dependency gates between tracks.

### Post-ship monitoring
After deploy, a lightweight monitoring agent that checks Datadog for error spikes or anomalies related to the change and posts a summary. Closes the loop between "PR merged" and "change is healthy in production."

### Docker containerisation
Run implement and test stages inside a container with the project directory mounted and no credentials outside what lint/tests need. See `docs/security-considerations.md` for the full analysis including the Docker-in-Docker tradeoff for services with Docker-based test suites.

### Fine-grained GitHub PAT
Replace `gh auth login` (broad credentials) with a fine-grained PAT scoped to specific repositories with only `contents: write` and `pull_requests: write`. See `docs/security-considerations.md`.
