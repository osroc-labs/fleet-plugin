# Fleet Social's shared helpers (social-hook, social-send, social-login). POSIX sh; sed, awk, curl, git and date only.
# A minimal copy of the fleet plugin's scripts/lib.sh (the config and JSON helpers), plus the local mood score.
# Byte-wise text handling everywhere, so invalid UTF-8 never trips sed or awk.
LC_ALL=C
export LC_ALL
umask 077

FLEET_DIR="${FLEET_HOME:-$HOME/.fleet}"
CONFIG="$FLEET_DIR/config.json"
# Fleet Social's own state: one small file per open session, what was last sent, its lock and its log.
SOC="$FLEET_DIR/social"
# The full fleet plugin's state: its hooks mark each session they report (wayfind/state/<session>.full).
WF="$FLEET_DIR/wayfind"
VERSION="0.1.0"
# A browser-like user agent (the API sits behind bot protection) that names the plugin, so its key is tagged social.
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0 Safari/537.36 fleet-social/$VERSION"

# One line to ~/.fleet/social/log; rotates at 256 KB. Never fails, never prints.
slog() {
  mkdir -p "$SOC" 2>/dev/null || return 0
  if [ -f "$SOC/log" ] && [ "$(wc -c <"$SOC/log" 2>/dev/null || echo 0)" -gt 262144 ]; then
    mv -f "$SOC/log" "$SOC/log.1" 2>/dev/null
  fi
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$SOC/log" 2>/dev/null
  return 0
}

# A top-level string value from a small JSON file ($1 file, $2 key). Nested objects are skipped.
json_file_get() {
  [ -f "$1" ] || return 0
  awk -v want="$2" '
    { s = s $0 "\n" }
    END {
      depth = 0; n = length(s); i = 1
      while (i <= n) {
        c = substr(s, i, 1)
        if (c == "\"") {
          rest = substr(s, i + 1)
          if (!match(rest, /^([^"\\]|\\.)*"/)) exit
          str = substr(rest, 1, RLENGTH - 1); i += RLENGTH + 1
          if (depth == 1 && expect_val) { if (key == want) { print str; exit } expect_val = 0; continue }
          if (depth == 1) { key = str; after = substr(s, i); if (match(after, /^[ \t\r\n]*:/)) { i += RLENGTH; expect_val = 1 } }
          continue
        }
        if (c == "{" || c == "[") depth++
        else if (c == "}" || c == "]") depth--
        else if (c != " " && c != "\t" && c != "\n" && c != "\r" && c != ",") expect_val = 0
        i++
      }
    }' "$1" 2>/dev/null
}

# The API key: FLEET_KEY, else "key" in ~/.fleet/config.json (the same file the fleet plugin uses).
fleet_key() {
  if [ -n "${FLEET_KEY:-}" ]; then printf '%s' "$FLEET_KEY"; return 0; fi
  json_file_get "$CONFIG" key
}

# The server: FLEET_SERVER, else "server" in config.json, else production.
fleet_server() {
  s="${FLEET_SERVER:-}"
  [ -n "$s" ] || s=$(json_file_get "$CONFIG" server)
  [ -n "$s" ] || s="https://fleet.osroc.io"
  printf '%s' "${s%/}"
}

# The decoded value of the first "$1": "…" string in the JSON on stdin.
json_get() {
  awk -v key="$1" '
    { s = (NR > 1) ? s "\n" $0 : $0 }
    END {
      if (!match(s, "\"" key "\"[ \t\r\n]*:[ \t\r\n]*\"")) exit
      s = substr(s, RSTART + RLENGTH)
      if (!match(s, /^([^"\\]|\\.)*/)) exit
      v = substr(s, 1, RLENGTH)
      gsub(/\\\\/, "\001", v)
      gsub(/\\"/, "\"", v); gsub(/\\\//, "/", v)
      gsub(/\\n/, "\n", v); gsub(/\\t/, "\t", v); gsub(/\\r/, "", v)
      gsub(/\\[bf]/, " ", v); gsub(/\\u[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]/, " ", v)
      gsub(/\001/, "\\", v)
      printf "%s", v
    }' 2>/dev/null
}

# Set top-level string field $2 to $3 in the JSON file $1 (config.json): replace a top-level "$2", else add it; every
# other field is left exactly as it was. A missing or empty file becomes {"$2":"$3"}. $3 must already be JSON-safe.
# Written 0600 through a temp file. Fails on bad JSON. (The fleet plugin's config_set, unchanged.)
config_set() {
  _cf=$1 _name=$2 _val=$3 _tmp="$1.tmp.$$"
  if [ -s "$_cf" ]; then
    awk -v name="$_name" -v val="$_val" '
      { s = (NR > 1) ? s "\n" $0 : $0 }
      END {
        n = length(s); depth = 0; i = 1; out = ""; done = 0; expect = 0
        while (i <= n) {
          c = substr(s, i, 1)
          if (c == "\"") {
            rest = substr(s, i + 1)
            if (!match(rest, /^([^"\\]|\\.)*"/)) { out = out substr(s, i); break }
            str = substr(rest, 1, RLENGTH - 1)
            if (depth == 1 && expect && k == name && !done) { out = out "\"" val "\""; done = 1 }
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
          if (!first) exit 1
          head = substr(out, 1, first); tail = substr(out, first + 1)
          empty = (tail ~ /^[ \t\r\n]*}/)
          out = head "\"" name "\":\"" val "\"" (empty ? "" : ",") tail
        }
        print out
      }' "$_cf" >"$_tmp" || { rm -f "$_tmp"; return 1; }
  else
    printf '{"%s":"%s"}\n' "$_name" "$_val" >"$_tmp" || return 1
  fi
  chmod 600 "$_tmp" && mv -f "$_tmp" "$_cf"
}

# Is mood scoring on? Off with "mood": "off" in ~/.fleet/config.json, or FLEET_SOCIAL_MOOD=off.
mood_on() {
  case "${FLEET_SOCIAL_MOOD:-}" in off | 0 | false | no) return 1 ;; esac
  case "$(json_file_get "$CONFIG" mood)" in off | false | no) return 1 ;; esac
  return 0
}

# The prompt on stdin, scored here and nowhere else: −2 (stormy) … +2 (delighted). Only the number leaves this function.
# The same heuristic as the Fleet CLI's local mood score (fleet/internal/wayfind/mood.go): frustrated and delighted
# phrases, swearing (celebratory swearing isn't anger), shouting in capitals. One fix: "hell" must be a whole word, so
# "hello" isn't swearing. It reads only the first 2 KB.
mood_score() {
  awk '
    BEGIN {
      nf = split("still broken|still not|still doesn'"'"'t|still does not|still fails|still failing|not working|doesn'"'"'t work|does not work|didn'"'"'t work|broken again|again?|why did you|why would you|why are you|i said|i told you|i already|you broke|regression|stop |stop.|stop!|no,|no.|wrong|undo|revert|useless|ugh|come on|what the|wtf|seriously|nuking|nuke|waste|terrible|awful|frustrat|annoying|ridiculous|never do|don'"'"'t ever", F, "|")
      nd = split("love it|love this|great|perfect|awesome|amazing|beautiful|nice|hell yeah|heck yeah|fuck yeah|fuck yes|yes!|yay|brilliant|excellent|nailed it|well done|good job|thank you|thanks|ship it|looks good|lgtm|fantastic|wonderful|\360\237\216\211|\360\237\224\245|\342\235\244\357\270\217|\360\237\231\214", D, "|")
      np = split("fuck shit damn hell crap bloody bastard goddamn", P, " ")
    }
    { s = (NR > 1) ? s "\n" $0 : $0 }
    # Occurrences of w in t that start a word (and, for "hell", end one too).
    function swears(t, w,   n, off, p, before, after) {
      n = 0; off = 0
      while ((p = index(substr(t, off + 1), w)) > 0) {
        p += off
        before = substr(t, p - 1, 1); after = substr(t, p + length(w), 1)
        if (before !~ /[a-z]/ && (w != "hell" || after !~ /[a-z]/)) n++
        off = p + length(w) - 1
      }
      return n
    }
    END {
      p = substr(s, 1, 2048)
      low = " " tolower(p) " "
      neg = 0; pos = 0
      for (i = 1; i <= nf; i++) if (index(low, F[i])) neg++
      for (i = 1; i <= nd; i++) if (index(low, D[i])) pos++
      swear = 0
      for (i = 1; i <= np; i++) swear += swears(low, P[i])
      celebrating = index(low, "yeah") || index(low, "yes") || pos > neg
      t = p; letters = gsub(/[A-Za-z]/, "", t)
      t = p; caps = gsub(/[A-Z]/, "", t)
      shouting = letters >= 12 && caps * 100 / letters >= 60
      score = pos - neg
      if (swear > 0) score += celebrating ? 1 : -1
      if (shouting && score <= 0) score--
      if (score > 2) score = 2
      if (score < -2) score = -2
      print score
    }' 2>/dev/null
}

# The project's display name for folder $1: the repo's folder name (the main checkout's, for a worktree), else the
# folder's own name. Never a path, never owner/repo. Letters, digits, dot, dash, underscore and spaces, 64 at most.
project_of() {
  d=$1 name=""
  if [ -d "$d" ]; then
    common=$(git -C "$d" rev-parse --git-common-dir 2>/dev/null)
    if [ -n "$common" ]; then
      top=$(cd "$d" 2>/dev/null && cd "$common" 2>/dev/null && pwd)
      case "$top" in
      */.git) name=$(basename "$(dirname "$top")") ;;
      ?*) name=$(basename "$top" .git) ;;
      esac
    fi
  fi
  [ -n "$name" ] || name=$(basename "$d" 2>/dev/null)
  name=$(printf '%s' "$name" | tr -cd 'A-Za-z0-9._ -' | cut -c 1-64)
  case "$name" in "" | . | ..) name="project" ;; esac
  printf '%s' "$name"
}

# Is the full fleet plugin reporting session $1? Its hooks mark it (0.6.1+), or registered it (older versions).
full_reports() {
  [ -f "$WF/state/$1.full" ] || [ -f "$WF/state/$1.opened" ]
}
