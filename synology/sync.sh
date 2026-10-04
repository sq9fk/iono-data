#!/bin/sh
# Keeps local copies of the antenna simulator pages (GitHub repositories, public or private) in /www for the web server:
# shallow clone once, then every SYNC_INTERVAL seconds a cheap ls-remote and, when the branch moved, fetch + hard reset;
# writes /www/index.html (tiles from home.html).
# Environment: REPOS (space separated, default the three antenna pages), BRANCH (main), SYNC_INTERVAL (s, default 60),
# SYNC_TOKEN (fine-grained token with Contents: read on these repositories, needed only when they are private).
REPOS="${REPOS:-sq9fk/anteny-sq9um sq9fk/anteny-sq9fk sq9fk/anteny-sp9pdf}"
BRANCH="${BRANCH:-main}"
SYNC_INTERVAL="${SYNC_INTERVAL:-60}"
[ "$SYNC_INTERVAL" -lt 30 ] && SYNC_INTERVAL=30
SYNC_TOKEN=$(printf %s "$SYNC_TOKEN" | tr -d '\r\n ')   # a .env saved with Windows line ends would leave a CR in the token
# the token goes only into an HTTP header of each git call, never into the clone's config (the copies are served by nginx)
g() {
  case "$SYNC_TOKEN" in
    ''|github_pat_xxxx*) git "$@" ;;
    *) git -c http.https://github.com/.extraHeader="Authorization: Basic $(printf 'x-access-token:%s' "$SYNC_TOKEN" | base64 | tr -d '\n')" "$@" ;;
  esac
}
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
    if [ "$SYNC_INTERVAL" -lt 120 ]; then every="$SYNC_INTERVAL s"; else every="$((SYNC_INTERVAL / 60)) min"; fi
    sed -i "s|@EVERY@|$every|g; s|@SYNC@|$(date -u '+%Y-%m-%d %H:%M')|g" "$t"
  else
    {
      echo '<!doctype html><html lang="pl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Anteny SQ9UM / SQ9FK / SP9PDF</title><h1>Symulatory anten KF</h1>'
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
      old=$(git -C "$d" rev-parse HEAD 2>/dev/null)
      remote=$(g ls-remote "https://github.com/$r.git" "refs/heads/$BRANCH" 2>/dev/null | cut -f1)
      if [ -z "$remote" ]; then
        [ "$warned" = "${warned#*$r}" ] && echo "$(date -u +%FT%TZ) $r: ls-remote failed (network, or a private repository without SYNC_TOKEN), keeping $(echo "$old" | cut -c1-7)" && warned="$warned $r"
      elif [ "$remote" != "$old" ]; then
        if g -C "$d" fetch -q --depth 1 origin "$BRANCH" && git -C "$d" reset -q --hard FETCH_HEAD && git -C "$d" clean -qfdx; then
          echo "$(date -u +%FT%TZ) $r: $(echo "$old" | cut -c1-7) -> $(git -C "$d" rev-parse --short HEAD)"; warned=$(echo "$warned" | sed "s| $r||")
        else
          echo "$(date -u +%FT%TZ) $r: fetch failed, keeping $(echo "$old" | cut -c1-7)"
        fi
      fi
    else
      rm -rf "$d"
      if g clone -q --depth 1 --branch "$BRANCH" "https://github.com/$r.git" "$d"; then echo "$(date -u +%FT%TZ) $r: cloned $(git -C "$d" rev-parse --short HEAD)"
      else echo "$(date -u +%FT%TZ) $r: clone failed (a private repository needs a valid SYNC_TOKEN)"; fi
    fi
  done
  page || echo "$(date -u +%FT%TZ) index page not written"
  sleep "$SYNC_INTERVAL"
done
