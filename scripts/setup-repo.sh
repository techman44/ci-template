#!/usr/bin/env bash
# Bootstrap a repo created from ci-template.
# Labels, template settings, and secrets do NOT copy with GitHub templates,
# so run this once per new repo:
#
#   ./scripts/setup-repo.sh                # current repo
#   ./scripts/setup-repo.sh owner/repo     # explicit repo
#   ./scripts/setup-repo.sh owner/repo --protect   # also add main branch protection
set -euo pipefail

REPO="${1:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
PROTECT="${2:-}"

echo "==> Configuring $REPO"

echo "==> Creating AI verdict labels"
gh label create "ai:claude-approved"          --repo "$REPO" --color 2ea44f --description "Claude review passed" --force
gh label create "ai:claude-changes-requested" --repo "$REPO" --color d73a4a --description "Claude review found blocking issues" --force
gh label create "ai:codex-approved"           --repo "$REPO" --color 2ea44f --description "Codex review passed" --force
gh label create "ai:codex-changes-requested"  --repo "$REPO" --color d73a4a --description "Codex review found blocking issues" --force

echo "==> Allowing GitHub Actions to approve pull requests (needed by the AI gate)"
gh api -X PUT "repos/$REPO/actions/permissions/workflow" \
  -f default_workflow_permissions=read \
  -F can_approve_pull_request_reviews=true

echo "==> Enabling auto-merge + delete-branch-on-merge"
gh api -X PATCH "repos/$REPO" \
  -F allow_auto_merge=true \
  -F delete_branch_on_merge=true >/dev/null

if [ "$PROTECT" = "--protect" ]; then
  echo "==> Protecting main: require CI 'test' check + 1 approval (free plan: public repos only)"
  gh api -X PUT "repos/$REPO/branches/main/protection" --input - <<'JSON'
{
  "required_status_checks": { "strict": true, "checks": [{ "context": "test" }] },
  "enforce_admins": false,
  "required_pull_request_reviews": { "required_approving_review_count": 1 },
  "restrictions": null
}
JSON
  echo "    NOTE: direct pushes to main are now blocked — everything goes through PRs."
fi

echo
echo "==> Done. Still needed (once per repo):"
echo "    gh secret set ANTHROPIC_API_KEY --repo $REPO   # or CLAUDE_CODE_OAUTH_TOKEN, see README"
echo "    gh secret set OPENAI_API_KEY    --repo $REPO"
