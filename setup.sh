#!/bin/sh
# Fleet for Claude Code: saves your Fleet key, then shows the two /plugin lines.
#   curl -fsSL https://fleet.osroc.io/setup.sh | sh -s -- fk_…
# It writes ~/.fleet/config.json (0600, merged: other keys are kept) and adds
# `export FLEET_KEY=…` to your shell's rc file once. Nothing else.
set -eu
umask 077

key="${1:-${FLEET_KEY:-}}"
case "$key" in
fk_*) ;;
*)
  echo "Usage: sh setup.sh fk_…   (get a key at https://fleet.osroc.io/app/keys)" >&2
  exit 1
  ;;
esac
case "$key" in *[!A-Za-z0-9_-]*)
  echo "That key has characters a Fleet key doesn't. Copy it again from https://fleet.osroc.io/app/keys" >&2
  exit 1
  ;;
esac

dir="${FLEET_HOME:-$HOME/.fleet}"
cfg="$dir/config.json"
mkdir -p "$dir"
chmod 700 "$dir"

# Merge "key" into config.json: replace a top-level "key", else add one. Every other field
# (server, runner, anything nested) is left exactly as it was.
tmp="$cfg.tmp.$$"
if [ -s "$cfg" ]; then
  LC_ALL=C awk -v key="$key" '
    { s = (NR > 1) ? s "\n" $0 : $0 }
    END {
      n = length(s); depth = 0; i = 1; out = ""; done = 0; expect = 0
      while (i <= n) {
        c = substr(s, i, 1)
        if (c == "\"") {
          rest = substr(s, i + 1)
          if (!match(rest, /^([^"\\]|\\.)*"/)) { out = out substr(s, i); break }
          str = substr(rest, 1, RLENGTH - 1)
          if (depth == 1 && expect && k == "key" && !done) { out = out "\"" key "\""; done = 1 }
          else out = out "\"" str "\""
          i += RLENGTH + 1
          if (depth == 1 && !expect) {
            after = substr(s, i)
            if (match(after, /^[ \t\r\n]*:/)) { k = str; out = out substr(after, 1, RLENGTH); i += RLENGTH; expect = 1; continue }
          }
          expect = 0
          continue
        }
        if (c == "{") { depth++; if (depth == 1) first = length(out) + 1 }
        else if (c == "}" || c == "]") depth--
        else if (c == "[") depth++
        if (c != " " && c != "\t" && c != "\n" && c != "\r" && c != "\"") expect = (c == ":") ? expect : 0
        out = out c
        i++
      }
      if (!done) {
        if (!first) { print "bad"; exit 1 }
        head = substr(out, 1, first); tail = substr(out, first + 1)
        empty = (tail ~ /^[ \t\r\n]*}/)
        out = head "\"key\":\"" key "\"" (empty ? "" : ",") tail
      }
      print out
    }' "$cfg" >"$tmp" || {
    echo "Couldn't read $cfg as JSON; left it alone. Fix it or move it aside, then run this again." >&2
    rm -f "$tmp"
    exit 1
  }
else
  printf '{"server":"https://fleet.osroc.io","key":"%s"}\n' "$key" >"$tmp"
fi
chmod 600 "$tmp"
mv -f "$tmp" "$cfg"
echo "Saved your key to $cfg"

# The shell rc: one export line, replaced if it's there already.
case "${SHELL:-}" in
*/zsh) rc="${ZDOTDIR:-$HOME}/.zshrc" ;;
*/bash) if [ "$(uname)" = Darwin ]; then rc="$HOME/.bash_profile"; else rc="$HOME/.bashrc"; fi ;;
*/fish) rc="" ;;
*) rc="$HOME/.profile" ;;
esac
if [ -n "$rc" ]; then
  touch "$rc"
  if grep -q '^export FLEET_KEY=' "$rc"; then
    sed "s|^export FLEET_KEY=.*\$|export FLEET_KEY='$key'  # Fleet (fleet-plugin)|" "$rc" >"$rc.fleet.$$" && cat "$rc.fleet.$$" >"$rc" && rm -f "$rc.fleet.$$"
  else
    printf "\nexport FLEET_KEY='%s'  # Fleet (fleet-plugin)\n" "$key" >>"$rc"
  fi
  echo "Added FLEET_KEY to $rc (open a new terminal, or: . $rc)"
else
  echo "fish: run  set -Ux FLEET_KEY $key"
fi

# Say hello to the fleet.
server=$(sed -n 's/.*"server"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$cfg" | head -n 1)
server="${server:-https://fleet.osroc.io}"
code=$(printf 'header = "Authorization: Bearer %s"\n' "$key" |
  curl -sS -K - -m 15 -o /dev/null -w '%{http_code}' \
    -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0 Safari/537.36 fleet-plugin/0.5.0" \
    "$server/api/voyages?open=1" 2>/dev/null || true)
case "$code" in
200) echo "Key works: the fleet answered." ;;
401) echo "Fleet didn't accept that key. Make a fresh one at $server/app/keys and run this again." >&2 ;;
*) echo "Couldn't reach $server just now (HTTP $code); the key is saved and will be used once it answers." ;;
esac

cat <<'EOF'

Now, in Claude Code:

  /plugin marketplace add osroc-labs/fleet-plugin
  /plugin install fleet@osroc

Fair winds.
EOF
