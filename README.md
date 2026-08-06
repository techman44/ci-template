# ci-template

Project template with CI + dual-AI code review, pre-wired:

- **CI** — auto-detects Node / Python / Go, runs lint + tests, and (if a `Dockerfile` exists) builds a Docker image. Pushes to `main` and `v*` tags publish the image to `ghcr.io/<owner>/<repo>`.
- **Claude review** — [claude-code-action](https://github.com/anthropics/claude-code-action) reviews every PR, leaves inline comments, and labels its verdict.
- **Codex review** — [codex-action](https://github.com/openai/codex-action) reviews the same PR read-only with a structured verdict, posted as a comment + label.
- **Cross-checked auto-approve** — only when **both** AIs label `approved` does the gate approve the PR and enable auto-merge. New commits wipe the verdicts and both reviews rerun.

## New project quick start

```bash
gh repo create my-app --template techman44/ci-template --public --clone
cd my-app
./scripts/setup-repo.sh                  # labels + repo settings (add --protect for branch protection)
gh secret set ANTHROPIC_API_KEY          # paste key, or: --body "$(op read ...)"
gh secret set OPENAI_API_KEY
```

Push a branch, open a PR, and watch the three workflows run.

> Templates copy **files only**. Labels, secrets, and repo settings don't come along — that's what `setup-repo.sh` and the two `gh secret set` calls are for.

## How a PR flows

1. `CI` runs detect → test → docker-build (image is built but not pushed on PRs).
2. `Claude Review` and `Codex Review` run in parallel. Each first removes its own old verdict label, reviews, comments, then labels `ai:claude-approved` / `ai:codex-approved` (or `...-changes-requested`).
3. Both review workflows end with the shared **AI gate** (`ai-gate.yml`). Whichever finishes second sees both `approved` labels, approves the PR as `github-actions`, and runs `gh pr merge --auto --squash`.
4. With branch protection requiring the `test` check, auto-merge waits for CI to go green on the latest commit before merging. Without branch protection the gate can only approve — auto-merge stays off (GitHub requires protection for it), so nothing merges behind your back.

To keep a human in the loop, delete the `gh pr merge --auto` line in `ai-gate.yml` — you'll still get both reviews and the auto-approval, but you press merge.

## Secrets

| Secret | Used by | Notes |
|---|---|---|
| `ANTHROPIC_API_KEY` | Claude review | From [console.anthropic.com](https://console.anthropic.com). **Or** use a Claude subscription: run `claude setup-token` locally, save as `CLAUDE_CODE_OAUTH_TOKEN`, and swap the commented line in `claude-review.yml`. |
| `OPENAI_API_KEY` | Codex review | From [platform.openai.com](https://platform.openai.com). |

PRs from forks don't get secrets, so AI reviews silently skip for them — fine for personal repos.

## Container images

With a `Dockerfile` present, pushes to `main` publish `ghcr.io/<owner>/<repo>:main` + `:sha-<short>`; tagging `v1.2.3` publishes `:1.2.3`. New GHCR packages default to private — flip to public in the package settings if wanted.

## Adding a deploy target later

The pipeline ends at a GHCR image, so deployment is one job away:

**Coolify** (self-hosted): create the app in Coolify pointing at the GHCR image, copy its webhook URL + API token, then append to `ci.yml`:

```yaml
  deploy:
    needs: docker
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - run: |
          curl -fsS -X GET "${{ secrets.COOLIFY_WEBHOOK }}" \
            -H "Authorization: Bearer ${{ secrets.COOLIFY_TOKEN }}"
```

**DigitalOcean / any docker host**: same shape — either `doctl apps create-deployment` with a DO API token, or SSH in and `docker compose pull && docker compose up -d`.

## Knobs

- **Blocking lint**: Python `ruff` is advisory (`|| true` in `ci.yml`) — remove it to make lint failures block.
- **Review triggers**: both review workflows skip drafts and rerun on every push (`synchronize`). Drop `synchronize` from `on.pull_request.types` to review only on open — cheaper, staler.
- **Merge style**: gate uses `--squash`; change to `--merge`/`--rebase` in `ai-gate.yml`.
- **Branch protection on private repos** needs GitHub Pro; public repos get it free (`setup-repo.sh --protect`).
