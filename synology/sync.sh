#!/bin/sh
# Keeps local copies of the antenna simulator pages (public GitHub Pages repositories) in /www for the web server:
# shallow clone once, then fetch + hard reset every SYNC_INTERVAL seconds; writes /www/index.html (tiles from home.html).
# Environment: REPOS (space separated, default the two antenna pages), BRANCH (main), SYNC_INTERVAL (s, default 900).
REPOS="${REPOS:-sq9fk/anteny-sq9um sq9fk/anteny-sq9fk}"
BRANCH="${BRANCH:-main}"
SYNC_INTERVAL="${SYNC_INTERVAL:-900}"
git config --global --add safe.directory '*'
# home page: tiles from /home.html (markers @VER_<repo>@, @CLS_<repo>@, @EVERY@, @SYNC@), or a plain list without it
page() {
  t=/www/index.html.tmp
  if [ -f /home.html ]; then
    cp /home.html "$t" || return 1
    for r in $REPOS; do
      n="${r#*/}"
      if [ -f "/www/$n/index.html" ]; then v="wersja $(git -C "/www/$n" log -1 --format='%h · %cd' --date=format:'%Y-%m-%d %H:%M' 2>/dev/null)"; c=""
      else v="jeszcze nie pobrano"; c="missing"; fi
      sed -i "s|@VER_$n@|$v|g; s|@CLS_$n@|$c|g" "$t"
    done
    sed -i "s|@EVERY@|$((SYNC_INTERVAL / 60))|g; s|@SYNC@|$(date -u '+%Y-%m-%d %H:%M')|g" "$t"
  else
    {
      echo '<!doctype html><html lang="pl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Anteny SQ9UM / SQ9FK</title><h1>Symulatory anten KF</h1>'
      for r in $REPOS; do n="${r#*/}"; [ -f "/www/$n/index.html" ] && echo "<p><a href=\"$n/\">$n</a></p>"; done
      echo '</html>'
    } > "$t" || return 1
  fi
  mv "$t" /www/index.html
}
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
  page || echo "$(date -u +%FT%TZ) index page not written"
  sleep "$SYNC_INTERVAL"
done
