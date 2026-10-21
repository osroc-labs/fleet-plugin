# Shared by fleet-api, fleet-login and fleet-headers. POSIX sh; sed, awk and curl only.
# Byte-wise text handling everywhere, so invalid UTF-8 never trips sed or awk.
LC_ALL=C
export LC_ALL
umask 077

FLEET_DIR="${FLEET_HOME:-$HOME/.fleet}"
CONFIG="$FLEET_DIR/config.json"

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

# Redact secrets from stdin before anything is shown. Order matters: specific keys first.
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
