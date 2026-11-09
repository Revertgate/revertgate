#!/usr/bin/env bash
# Runs the Revertgate binary for a pull_request event, then posts (or updates) the PR comment.
set -euo pipefail

if [ -z "${BASE_SHA:-}" ]; then
  echo "::error title=Revertgate::Revertgate runs on pull_request events (no base commit found)"
  exit 2
fi
if [ "$(uname -s)-$(uname -m)" != "Linux-x86_64" ]; then
  echo "::error title=Revertgate::Revertgate ships a Linux x64 binary; run it on ubuntu-latest"
  exit 2
fi

bin="$(dirname "$0")/bin/revertgate-linux-x64"
if [ ! -x "$bin" ]; then
  chmod +x "$bin"
fi
report="${RUNNER_TEMP:-/tmp}/revertgate.md"
args=(check --base "$BASE_SHA" --head HEAD --format github --markdown-out "$report")
if [ -n "${REVERTGATE_TEST:-}" ]; then
  args+=(--test "$REVERTGATE_TEST")
fi
if [ "${REVERTGATE_OVERRIDE:-false}" = "true" ]; then
  args+=(--override)
fi

status=0
"$bin" "${args[@]}" || status=$?

# Revertgate's own comment carries this marker, so it is the one updated on each push and
# another bot's comment is never overwritten.
marker='<!-- revertgate-report -->'
post_comment() {
  local body="${RUNNER_TEMP:-/tmp}/revertgate-comment.md" id
  { echo "$marker"; cat "$report"; } > "$body"
  id=$(gh api --paginate "repos/$GH_REPO/issues/$PR_NUMBER/comments" \
    --jq ".[] | select(.body | startswith(\"$marker\")) | .id" | tail -n 1) || return 1
  if [ -n "$id" ]; then
    gh api -X PATCH "repos/$GH_REPO/issues/comments/$id" -F "body=@$body" >/dev/null
  else
    gh api -X POST "repos/$GH_REPO/issues/$PR_NUMBER/comments" -F "body=@$body" >/dev/null
  fi
}

if [ "${REVERTGATE_COMMENT:-true}" = "true" ] && [ -n "${PR_NUMBER:-}" ] && [ -s "$report" ]; then
  err="${RUNNER_TEMP:-/tmp}/revertgate-comment.err"
  if ! post_comment 2>"$err"; then
    # Fork PRs get a read-only token. The check result and the job summary still stand,
    # so a missing comment is reported, not fatal.
    echo "::warning title=Revertgate::could not post the PR comment: $(head -c 300 "$err")"
  fi
fi
exit "$status"
