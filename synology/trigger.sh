#!/bin/sh
# Starts the relay workflow on GitHub every INTERVAL seconds (workflow_dispatch). GitHub runs dispatched workflows at once,
# while its own schedule of a little-used public repository is often delayed by hours.
# Environment: GITHUB_TOKEN (fine-grained, this repository only, Actions: read and write), optional REPO, WORKFLOW, REF,
# INTERVAL (s, at least 300: PSK Reporter asks for at most one query every 5 minutes), ONCE=1 (one call, then exit – for a test).
REPO="${REPO:-sq9fk/iono-data}"
WORKFLOW="${WORKFLOW:-iono.yml}"
REF="${REF:-main}"
INTERVAL="${INTERVAL:-900}"
[ "$INTERVAL" -lt 300 ] && INTERVAL=300
GITHUB_TOKEN=$(printf %s "$GITHUB_TOKEN" | tr -d '\r\n ')   # a .env saved with Windows line ends would leave a CR in the token
case "$GITHUB_TOKEN" in ''|github_pat_xxxx*) echo "GITHUB_TOKEN is not set (see .env.example) – the relay is not triggered, waiting"; exec sleep 2147483647;; esac
URL="https://api.github.com/repos/$REPO/actions/workflows/$WORKFLOW/dispatches"
echo "$(date -u +%FT%TZ) starting: $REPO $WORKFLOW every $INTERVAL s"
while :; do
  code=$(curl -s -o /tmp/resp -w '%{http_code}' -X POST "$URL" \
    -H "Authorization: Bearer $GITHUB_TOKEN" -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' -H 'User-Agent: sq9fk-iono-trigger' \
    --max-time 60 -d "{\"ref\":\"$REF\"}")
  case "$code" in
    204) echo "$(date -u +%FT%TZ) dispatched" ;;
    401|403|404) echo "$(date -u +%FT%TZ) HTTP $code – check the token (repository $REPO, Actions: read and write): $(head -c 200 /tmp/resp)" ;;
    *) echo "$(date -u +%FT%TZ) HTTP $code $(head -c 200 /tmp/resp)" ;;
  esac
  [ "$ONCE" = "1" ] && exit 0
  sleep "$INTERVAL"
done
