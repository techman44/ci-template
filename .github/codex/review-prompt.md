You are reviewing a pull request. The repository is checked out at the PR's merge commit, and the full diff against the base branch is in `pr-diff.txt` at the repository root.

Read `pr-diff.txt` first, then read surrounding source files for context wherever the diff alone is ambiguous.

Review for:
- correctness bugs and unhandled edge cases
- security vulnerabilities
- performance regressions
- serious maintainability problems

Style nitpicks and personal preferences are worth mentioning in the summary but are NOT blocking.

Respond with JSON matching the provided output schema:
- `verdict`: `"approve"` if there are no blocking issues, otherwise `"request_changes"`
- `summary`: 2–6 sentences describing the change and your assessment
- `issues`: concrete problems found (empty array if none); reference file and line where possible
