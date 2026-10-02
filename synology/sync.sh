#!/bin/sh
# Keeps local copies of the antenna simulator pages (public GitHub Pages repositories) in /www for the web server:
# shallow clone once, then fetch + hard reset every SYNC_INTERVAL seconds; writes /www/index.html with links to both.
# Environment: REPOS (space separated, default the two antenna pages), BRANCH (main), SYNC_INTERVAL (s, default 900).
REPOS="${REPOS:-sq9fk/anteny-sq9um sq9fk/anteny-sq9fk}"
BRANCH="${BRANCH:-main}"
SYNC_INTERVAL="${SYNC_INTERVAL:-900}"
git config --global --add safe.directory '*'
while :; do
  for r in $REPOS; do
    d="/www/${r#*/}"
    if [ -d "$d/.git" ]; then
      old=$(git -C "$d" rev-parse --short HEAD 2>/dev/null)
      if git -C "$d" fetch -q --depth 1 origin "$BRANCH" && git -C "$d" reset -q --hard FETCH_HEAD && git -C "$d" clean -qfdx; then
        new=$(git -C "$d" rev-parse --short HEAD)
        [ "$old" != "$new" ] && echo "$(date -u +%FT%TZ) $r: $old -> $new"
      else
        echo "$(date -u +%FT%TZ) $r: fetch failed, keeping $old"
      fi
    else
      rm -rf "$d"
      if git clone -q --depth 1 --branch "$BRANCH" "https://github.com/$r.git" "$d"; then echo "$(date -u +%FT%TZ) $r: cloned $(git -C "$d" rev-parse --short HEAD)"
      else echo "$(date -u +%FT%TZ) $r: clone failed"; fi
    fi
  done
  {
    echo '<!doctype html><html lang="pl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
    echo '<title>Anteny SQ9FK / SQ9UM</title><style>body{font:16px/1.5 system-ui,sans-serif;max-width:640px;margin:40px auto;padding:0 16px}a{display:block;margin:8px 0;font-size:18px}small{color:#666}</style>'
    echo '<h1>Symulatory anten KF</h1>'
    for r in $REPOS; do
      n="${r#*/}"
      [ -f "/www/$n/index.html" ] && echo "<a href=\"$n/\">$n</a><small>wersja $(git -C "/www/$n" log -1 --format='%h z %cd' --date=format:'%Y-%m-%d %H:%M' 2>/dev/null)</small>"
    done
    echo "<p><small>Kopie stron z GitHub Pages, odświeżane co $((SYNC_INTERVAL / 60)) min; ostatnio $(date -u '+%Y-%m-%d %H:%M') UTC.</small></p></html>"
  } > /www/index.html.tmp && mv /www/index.html.tmp /www/index.html
  sleep "$SYNC_INTERVAL"
done
