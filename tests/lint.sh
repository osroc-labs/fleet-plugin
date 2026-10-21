#!/bin/sh
# The plugin is well formed: every shell script parses, every JSON file is valid, every command and skill has
# frontmatter, and every script a command runs exists. Run: sh tests/lint.sh
ROOT=$(cd "$(dirname "$0")/.." && pwd)
bad=0
fail() { echo "FAIL lint: $*"; bad=1; }

for f in "$ROOT"/scripts/* "$ROOT"/setup.sh "$ROOT"/tests/*.sh; do
  sh -n "$f" 2>/dev/null || fail "$(basename "$f") doesn't parse"
done

for f in "$ROOT"/.claude-plugin/*.json "$ROOT"/.mcp.json; do
  python3 -I -c 'import json,sys; json.load(open(sys.argv[1]))' "$f" 2>/dev/null || fail "${f#"$ROOT"/} isn't valid JSON"
done

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
