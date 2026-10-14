# Shared by fleet-hook, fleet-send and fleet-headers. POSIX sh; sed, awk, curl, git and date only.
# Byte-wise text handling everywhere, so invalid UTF-8 never trips sed or awk.
LC_ALL=C
export LC_ALL
umask 077

FLEET_DIR="${FLEET_HOME:-$HOME/.fleet}"
WF="$FLEET_DIR/wayfind"
CONFIG="$FLEET_DIR/config.json"

# One line to ~/.fleet/wayfind/log; rotates at 1 MB. Never fails.
flog() {
  mkdir -p "$WF" 2>/dev/null || return 0
  if [ -f "$WF/log" ] && [ "$(wc -c <"$WF/log" 2>/dev/null || echo 0)" -gt 1048576 ]; then
    mv -f "$WF/log" "$WF/log.1" 2>/dev/null
  fi
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$WF/log" 2>/dev/null
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

# A top-level value from a small JSON file ($1 file, $2 key), string or literal (false, 0, null…), as written; nested
# objects and arrays are skipped whole, so a key of the same name inside them never counts.
json_top() {
  [ -f "$1" ] || return 0
  awk -v want="$2" '
    { s = s $0 "\n" }
    END {
      depth = 0; n = length(s); i = 1; ek = 1; key = ""
      while (i <= n) {
        c = substr(s, i, 1)
        if (c == "\"") {
          rest = substr(s, i + 1)
          if (!match(rest, /^([^"\\]|\\.)*"/)) exit
          str = substr(rest, 1, RLENGTH - 1); i += RLENGTH + 1
          if (depth != 1) continue
          if (ek) key = str
          else if (key == want) { print str; exit }
          continue
        }
        if (depth == 1 && !ek && c ~ /[A-Za-z0-9.+-]/) {
          rest = substr(s, i); match(rest, /^[A-Za-z0-9.+-]+/)
          if (key == want) { print substr(rest, 1, RLENGTH); exit }
          i += RLENGTH; continue
        }
        if (c == "{" || c == "[") depth++
        else if (c == "}" || c == "]") depth--
        else if (depth == 1 && c == ",") ek = 1
        else if (depth == 1 && c == ":") ek = 0
        i++
      }
    }' "$1" 2>/dev/null
}

# Is sending Claude's replies turned off? "replies": false (or "false", "off", "no", 0) at the top level of
# ~/.fleet/config.json, or of .fleet/workflow.json in the repo of the session's folder $1 (its git root, else the folder).
replies_off() {
  for _rf in "$CONFIG" "${1:+$(git -C "$1" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$1")/.fleet/workflow.json}"; do
    [ -n "$_rf" ] && [ -f "$_rf" ] || continue
    case "$(json_top "$_rf" replies)" in false | off | no | 0 | False | FALSE | Off | OFF | No | NO) return 0 ;; esac
  done
  return 1
}

# The API key: FLEET_KEY, else "key" in ~/.fleet/config.json.
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

# Escape stdin as the inside of a JSON string, after cutting it to $1 bytes (0 = no cut) on a
# UTF-8 boundary, with an ellipsis when cut. Control characters become spaces.
json_text() {
  awk -v max="${1:-0}" '
    function cut(s, n,   i, c, need, L) {
      s = substr(s, 1, n); L = length(s)
      for (i = L; i > 0 && i > L - 4; i--) {
        c = substr(s, i, 1)
        if (c < "\200") return s
        if (c >= "\300") {
          need = (c >= "\360") ? 4 : (c >= "\340") ? 3 : 2
          return (L - i + 1 < need) ? substr(s, 1, i - 1) : s
        }
      }
      return s
    }
    { s = (NR > 1) ? s "\n" $0 : $0 }
    END {
      sub(/^[ \t\n\r]+/, "", s); sub(/[ \t\n\r]+$/, "", s)
      if (max > 0 && length(s) > max) { s = cut(s, max - 3); sub(/[ \t\n\r]+$/, "", s); s = s "\342\200\246" }
      gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s)
      gsub(/\n/, "\\n", s); gsub(/\t/, "\\t", s); gsub(/\r/, "", s)
      gsub(/[\001-\037\177]/, " ", s)
      printf "%s", s
    }'
}

# Redact secrets from stdin before anything is queued. Order matters: specific keys first.
redact() {
  sed -E \
    -e '/-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----/,/-----END [A-Z0-9 ]*PRIVATE KEY-----/c\
[redacted:pem]' \
    -e 's/(^|[^A-Za-z0-9_-])sk-[A-Za-z0-9_-]{16,}/\1[redacted:key]/g' \
    -e 's/(^|[^A-Za-z0-9_])[rsp]k_(live|test)_[A-Za-z0-9]{10,}/\1[redacted:key]/g' \
    -e 's/(^|[^A-Za-z0-9_])f[krj]_[A-Za-z0-9_-]{8,}/\1[redacted:fleet]/g' \
    -e 's/(^|[^A-Za-z0-9_])github_pat_[A-Za-z0-9_]{20,}/\1[redacted:github]/g' \
    -e 's/(^|[^A-Za-z0-9_])gh[pousr]_[A-Za-z0-9]{20,}/\1[redacted:github]/g' \
    -e 's/(^|[^A-Za-z0-9_])xox[abprs]-[A-Za-z0-9-]{10,}/\1[redacted:slack]/g' \
    -e 's/(^|[^A-Za-z0-9])(AKIA|ASIA)[A-Z0-9]{16}/\1[redacted:aws]/g' \
    -e 's/([Aa][Ww][Ss]_?[Ss][Ee][Cc][Rr][Ee][Tt]_?[Aa][Cc][Cc][Ee][Ss][Ss]_?[Kk][Ee][Yy]["'"'"']?[[:space:]]*[=:][[:space:]]*["'"'"']?)[A-Za-z0-9/+=]{30,}/\1[redacted:aws]/g' \
    -e 's/(^|[^A-Za-z0-9_])AIza[0-9A-Za-z_-]{35}/\1[redacted:google]/g' \
    -e 's/(^|[^A-Za-z0-9_])eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}/\1[redacted:jwt]/g' \
    -e 's/([Bb][Ee][Aa][Rr][Ee][Rr][[:space:]]+)[A-Za-z0-9._~+\/-]{8,}=*/\1[redacted:bearer]/g' \
    -e 's#([a-zA-Z][a-zA-Z0-9+.-]*://[^[:space:]:/@]+:)[^[:space:]@/]+@#\1[redacted]@#g' \
    -e 's/(([Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]|[Pp][Aa][Ss][Ss][Ww][Dd]|[Pp][Ww][Dd]|[Pp][Aa][Ss][Ss][Pp][Hh][Rr][Aa][Ss][Ee])["'"'"']?[[:space:]]*[=:][[:space:]]*["'"'"']?)[^[:space:]"'"'"',;&]+/\1[redacted:password]/g' \
    -e 's/^([[:space:]]*(export[[:space:]]+)?[A-Z0-9_]*(SECRET|TOKEN|PASSWORD|PASSWD|KEY|CREDENTIAL|CREDENTIALS|AUTH|DSN|COOKIE)[A-Z0-9_]*[[:space:]]*=[[:space:]]*)[^[:space:]].*$/\1[redacted:env]/' \
    -e 's/(^|[^A-Za-z0-9_])([A-Z0-9_]*(SECRET|TOKEN|PASSWORD|PASSWD|KEY)[A-Z0-9_]*=)[^[:space:]"'"'"'[]+/\1\2[redacted:env]/g'
}

# The decoded value of the first "$2": "…" string in the JSON in file $1, from the first match
# of "$3" on (optional, a key that must come first, such as tool_response). Key names can't
# occur inside JSON string values unescaped, so the first match is the real key.
json_get() {
  awk -v key="$2" -v after="${3:-}" '
    { s = (NR > 1) ? s "\n" $0 : $0 }
    END {
      if (after != "") { if (!match(s, "\"" after "\"[ \t\r\n]*:")) exit; s = substr(s, RSTART + RLENGTH) }
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
    }' "$1" 2>/dev/null
}

# awk functions shared by human_text and transcript_turns: human(s) is what the person actually typed in prompt s
# (newlines as \n or \001). Claude Code also submits injected text as prompts: subagent hand-backs (<agent-message>),
# <task-notification>, <system-reminder>, local-command plumbing. Those blocks are cut; a slash command becomes
# "/command args" and a ! bash line "! command". Empty means nothing human: skip the prompt.
HUMAN_AWK='
function h_open(s, tag,   off, p, c) {
  off = 0
  while ((p = index(substr(s, off + 1), "<" tag)) > 0) {
    p += off
    c = substr(s, p + length(tag) + 1, 1)
    if (c == ">" || c == " " || c == "/" || c == "\n" || c == "\001" || c == "\t" || c == "\r") return p
    off = p
  }
  return 0
}
function h_cut(s, tag,   a, rest, e, n) {
  n = 0
  while ((a = h_open(s, tag)) > 0 && n++ < 50) {
    rest = substr(s, a)
    e = index(rest, "</" tag ">")
    if (e == 0) { s = substr(s, 1, a - 1); break }
    s = substr(s, 1, a - 1) substr(rest, e + length(tag) + 3)
  }
  return s
}
function h_inner(s, tag,   a, rest, g, e) {
  if (!(a = h_open(s, tag))) return ""
  rest = substr(s, a); g = index(rest, ">"); if (!g) return ""
  rest = substr(rest, g + 1); e = index(rest, "</" tag ">")
  return e ? substr(rest, 1, e - 1) : rest
}
function h_trim(s) { sub(/^[ \t\r\n\001]+/, "", s); sub(/[ \t\r\n\001]+$/, "", s); return s }
function h_line(s) { gsub(/[\t\r\n\001]+/, " ", s); s = h_trim(s); return (length(s) > 200) ? substr(s, 1, 200) : s }
function human(s,   n, i, T, c, a, t) {
  n = split("agent-message task-notification system-reminder local-command-caveat local-command-stdout local-command-stderr bash-stdout bash-stderr user-prompt-submit-hook teammate-message", T, " ")
  for (i = 1; i <= n; i++) s = h_cut(s, T[i])
  c = h_line(h_inner(s, "command-name"))
  if (c != "") {
    if (substr(c, 1, 1) != "/") c = "/" c
    a = h_line(h_inner(s, "command-args"))
    return (a != "") ? c " " a : c
  }
  c = h_line(h_inner(s, "bash-input"))
  if (c != "") return "! " c
  s = h_cut(h_cut(h_cut(s, "command-message"), "command-args"), "command-contents")
  s = h_trim(s)
  # Any other leading <hyphenated-tag>…</hyphenated-tag> block is plumbing too.
  for (i = 0; i < 20 && match(s, /^<[a-z]+(-[a-z]+)+[ >\/\n\001]/); i++) {
    t = substr(s, 2, RLENGTH - 2)
    s = h_trim(h_cut(s, t))
  }
  return s
}
'

# What the person typed, from the prompt on stdin (see HUMAN_AWK). Prints nothing when it was all injected text.
human_text() {
  awk "$HUMAN_AWK"'
    { s = (NR > 1) ? s "\n" $0 : $0 }
    END { printf "%s", human(s) }'
}

# The session's latest name from transcript $1, raw JSON-escaped: /rename's custom-title line (Claude Code's own
# auto titles are not names). Cheap: grep and tail.
transcript_title() {
  [ -f "$1" ] || return 0
  for spec in custom-title:customTitle; do
    typ=${spec%%:*}
    key=${spec#*:}
    line=$(grep -E "\"type\"[ ]*:[ ]*\"$typ\"" "$1" 2>/dev/null | tail -n 1)
    [ -n "$line" ] || continue
    v=$(printf '%s\n' "$line" | awk -v key="$key" '
      match($0, "\"" key "\"[ ]*:[ ]*\"") {
        s = substr($0, RSTART + RLENGTH)
        if (match(s, /^([^"\\]|\\.)*/)) printf "%s", substr(s, 1, RLENGTH)
      }')
    [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  done
}

# The conversation in transcript $1 (Claude Code's JSONL): the person's typed prompts and Claude's replies, text only,
# one record per line, tab-separated:
#   P <turn> <timestamp> <prompt>   what the person typed (HUMAN_AWK), newlines as \001
#   R <turn> <timestamp> <reply>    Claude's final text for a turn, still JSON-escaped
# (the timestamp is the line's own, "-" when it has none).
# $2: read only the first $2 lines (0 = all); $3: only the last $3 lines (0 = all); $4: keep the last $4 turns (0 = all).
# A turn's reply is the assistant text after its last tool round (what the Stop hook calls last_assistant_message):
# a tool result drops the text before it, and any other user line (a prompt, an injected notice) ends the reply.
# Never read: tool calls and their input, tool results, thinking, subagent (sidechain) lines. Assistant lines are walked
# as JSON, so only message.content[] blocks of type "text" count; huge lines without a text block are skipped unread.
transcript_turns() {
  [ -f "$1" ] || return 0
  _tt="$WF/tmp/turns.$$"
  mkdir -p "$WF/tmp" 2>/dev/null
  if [ "${2:-0}" -gt 0 ] 2>/dev/null; then head -n "$2" "$1"; elif [ "${3:-0}" -gt 0 ] 2>/dev/null; then tail -n "$3" "$1"; else cat "$1"; fi 2>/dev/null |
    awk "$HUMAN_AWK"'
    # Odd number of trailing backslashes: the quote that followed was escaped.
    function bsodd(s) { return match(s, /\\+$/) && RLENGTH % 2 == 1 }
    # Walk one JSON line: top-level type, isSidechain and timestamp, and the text of message.content[] text blocks
    # (still escaped, joined by a blank line). Strings are found by splitting on quotes, so it is linear in the line.
    function walk(s,   np, P, Q, m, k, str, j, seg, L, x, c, lit, d, ct, ek, key, inMsg, inC, inB, bt, bx) {
      A_type = ""; A_side = 0; A_ts = ""; A_text = ""
      np = split(s, P, "\"")
      m = 1; Q[1] = P[1]; k = 2
      while (k <= np) {
        str = P[k]; k++
        while (bsodd(str) && k <= np) { str = str "\"" P[k]; k++ }
        Q[++m] = str
        Q[++m] = (k <= np) ? P[k++] : ""
      }
      d = 0; inMsg = 0; inC = 0; inB = 0
      for (j = 1; j <= m; j++) {
        if (j % 2 == 0) {
          str = Q[j]
          if (ct[d] == "o" && ek[d]) { key[d] = str; continue }
          if (d == 1 && key[1] == "type") A_type = str
          else if (d == 1 && key[1] == "timestamp") A_ts = str
          else if (d == 2 && inMsg && key[2] == "content") A_text = str
          else if (d == 4 && inB && key[4] == "type") bt = str
          else if (d == 4 && inB && key[4] == "text") bx = str
          continue
        }
        seg = Q[j]; L = length(seg); lit = ""
        for (x = 1; x <= L + 1; x++) {
          c = (x <= L) ? substr(seg, x, 1) : " "
          if (c ~ /[A-Za-z0-9.+-]/) { lit = lit c; continue }
          if (lit != "") { if (d == 1 && key[1] == "isSidechain" && lit == "true") A_side = 1; lit = "" }
          if (c == "{") {
            d++; ct[d] = "o"; ek[d] = 1; key[d] = ""
            if (d == 2 && key[1] == "message") inMsg = 1
            if (d == 4 && inC) { inB = 1; bt = ""; bx = "" }
          } else if (c == "[") {
            d++; ct[d] = "a"
            if (d == 3 && inMsg && key[2] == "content") inC = 1
          } else if (c == "}") {
            if (d == 4 && inB) { if (bt == "text" && bx != "") A_text = (A_text == "") ? bx : A_text "\\n\\n" bx; inB = 0 }
            if (d == 2) inMsg = 0
            d--
          } else if (c == "]") {
            if (d == 3) inC = 0
            d--
          } else if (c == ",") { if (ct[d] == "o") ek[d] = 1 }
          else if (c == ":") { if (ct[d] == "o") ek[d] = 0 }
        }
      }
    }
    function stamp(s,   t) {
      t = ""
      while (match(s, /"timestamp"[ ]*:[ ]*"[0-9T:.Z+-]+"/)) { t = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH) }
      sub(/^"timestamp"[ ]*:[ ]*"/, "", t); sub(/"$/, "", t)
      return t
    }
    function clip(s, n) { if (length(s) <= n) return s; s = substr(s, 1, n); if (match(s, /\\+$/) && RLENGTH % 2 == 1) s = substr(s, 1, length(s) - 1); return s }
    function reply() { if (buf != "") print "R\t" turn "\t" (bts == "" ? "-" : bts) "\t" clip(buf, 40000); buf = "" }
    BEGIN { turn = 0; buf = "" }
    /"type"[ ]*:[ ]*"assistant"/ && /"type"[ ]*:[ ]*"text"/ {
      walk($0)
      if (A_type == "assistant") {
        if (!A_side && A_text != "") { buf = (buf == "") ? A_text : buf "\\n\\n" A_text; bts = A_ts }
        next
      }
    }
    !/"type"[ ]*:[ ]*"user"/ { next }
    /"isSidechain"[ ]*:[ ]*true/ { next }
    /"tool_use_id"[ ]*:/ || /"toolUseResult"[ ]*:/ { buf = ""; next }
    {
      reply()
      if (/"isMeta"[ ]*:[ ]*true/ || /"isCompactSummary"[ ]*:[ ]*true/) next
      s = $0; ts = stamp(s)
      if (!match(s, /"message"[ ]*:[ ]*\{/)) next
      s = substr(s, RSTART + RLENGTH)
      if (!match(s, /"content"[ ]*:[ ]*/)) next
      s = substr(s, RSTART + RLENGTH)
      if (substr(s, 1, 1) != "\"") {
        if (!match(s, /"type"[ ]*:[ ]*"text"[ ]*,[ ]*"text"[ ]*:[ ]*"/)) next
        s = substr(s, RSTART + RLENGTH)
      } else s = substr(s, 2)
      if (!match(s, /^([^"\\]|\\.)*/)) next
      v = substr(s, 1, RLENGTH)
      gsub(/\\\\/, "\002", v)
      gsub(/\\"/, "\"", v); gsub(/\\\//, "/", v)
      gsub(/\\n/, "\001", v); gsub(/\\t/, " ", v); gsub(/\\r/, "", v)
      gsub(/\\[bf]/, " ", v); gsub(/\\u[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]/, " ", v)
      gsub(/\002/, "\\", v)
      v = human(v)
      if (v ~ /^[ \001]*$/) next
      if (v ~ /^\[Request interrupted/ || v ~ /^Caveat: /) next
      turn++
      print "P\t" turn "\t" (ts == "" ? "-" : ts) "\t" substr(v, 1, 40000)
    }
    END { reply() }' >"$_tt" 2>/dev/null
  awk -F '\t' -v keep="${4:-0}" 'NR == FNR { if ($2 > max) max = $2; next } keep == 0 || $2 > max - keep' "$_tt" "$_tt" 2>/dev/null
  rm -f "$_tt"
}

# Several short top-level fields at once from the JSON in file $1, one per line, reduced to
# [A-Za-z0-9_.:/-]. The last line is 1 when the tool's result holds an https:// link, else 0.
json_fields() {
  f=$1
  shift
  awk -v keys="$*" '
    { s = (NR > 1) ? s "\n" $0 : $0 }
    END {
      n = split(keys, k, " ")
      for (j = 1; j <= n; j++) {
        v = ""
        if (match(s, "\"" k[j] "\"[ \t\r\n]*:[ \t\r\n]*\"")) {
          r = substr(s, RSTART + RLENGTH)
          if (match(r, /^([^"\\]|\\.)*/)) v = substr(r, 1, RLENGTH)
        }
        gsub(/[^A-Za-z0-9_.:\/-]/, "", v)
        print v
      }
      u = 0
      if (match(s, /"tool_response"[ \t]*:/) && index(substr(s, RSTART), "https://")) u = 1
      print u
    }' "$f" 2>/dev/null
}

# Decode a JSON string body (no surrounding quotes) on stdin to text.
json_unescape() {
  awk '
    { s = (NR > 1) ? s "\n" $0 : $0 }
    END {
      gsub(/\\\\/, "\001", s)
      gsub(/\\"/, "\"", s); gsub(/\\\//, "/", s)
      gsub(/\\n/, "\n", s); gsub(/\\t/, "\t", s); gsub(/\\r/, "", s)
      gsub(/\\[bf]/, " ", s); gsub(/\\u[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]/, " ", s)
      gsub(/\001/, "\\", s)
      printf "%s", s
    }'
}

# Set top-level string field $2 to $3 in the JSON file $1 (config.json), the way setup.sh merges its key: replace a
# top-level "$2", else add it; every other field (server, runner, anything nested) is left exactly as it was. A missing
# or empty file becomes {"$2":"$3"}. $3 must already be JSON-safe. Written 0600 through a temp file. Fails on bad JSON.
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
