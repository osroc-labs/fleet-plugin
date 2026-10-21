#!/bin/sh
# The plugin is well formed: every shell script parses, every JSON file is valid, every command and skill has
# frontmatter, and every script a command runs exists. Run: sh tests/lint.sh
ROOT=$(cd "$(dirname "$0")/.." && pwd)
bad=0
fail() { echo "FAIL lint: $*"; bad=1; }

for f in "$ROOT"/scripts/* "$ROOT"/setup.sh "$ROOT"/tests/*.sh; do
  sh -n "$f" 2>/dev/null || fail "$(basename "$f") doesn't parse"
done

# Valid JSON, with whichever parser this machine has: python3, node, or macOS's plutil.
json_ok() {
  if command -v python3 >/dev/null 2>&1; then python3 -I -c 'import json,sys; json.load(open(sys.argv[1]))' "$1" 2>/dev/null
  elif command -v node >/dev/null 2>&1; then node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$1" 2>/dev/null
  elif command -v plutil >/dev/null 2>&1; then plutil -lint -s "$1" >/dev/null 2>&1
  else echo "skip: no python3, node or plutil to check JSON"; return 0
  fi
}
for f in "$ROOT"/.claude-plugin/*.json "$ROOT"/.mcp.json; do
  json_ok "$f" || fail "${f#"$ROOT"/} isn't valid JSON"
done

# The MCP's headersHelper points at a script that exists.
helper=$(sed -n 's/.*"headersHelper"[^"]*"sh \\"\${CLAUDE_PLUGIN_ROOT}\/\([^"\\]*\)\\"".*/\1/p' "$ROOT/.mcp.json")
[ -n "$helper" ] || fail ".mcp.json has no headersHelper of the form sh \"\${CLAUDE_PLUGIN_ROOT}/…\""
[ -z "$helper" ] || [ -f "$ROOT/$helper" ] || fail ".mcp.json headersHelper runs $helper, which doesn't exist"

for f in "$ROOT"/commands/*.md "$ROOT"/skills/*/SKILL.md; do
  [ "$(head -n 1 "$f")" = "---" ] || fail "${f#"$ROOT"/} has no frontmatter"
  grep -q '^description:' "$f" || fail "${f#"$ROOT"/} has no description"
done

for f in "$ROOT"/commands/*.md; do
  for s in $(grep -o 'scripts/[a-z-]*' "$f" | sort -u); do
    [ -f "$ROOT/$s" ] || fail "${f#"$ROOT"/} runs $s, which doesn't exist"
  done
done

[ "$bad" = 0 ] && echo "ok lint"
exit $bad
