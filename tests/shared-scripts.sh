#!/bin/sh
# The sub-plugins (sims/, workflows/) are installed on their own, so each carries copies of the helpers it uses from
# scripts/. This checks every copy still matches scripts/: edit scripts/, then copy. Run: sh tests/shared-scripts.sh
ROOT=$(cd "$(dirname "$0")/.." && pwd)
bad=0
for f in "$ROOT"/sims/scripts/* "$ROOT"/workflows/scripts/*; do
  name=$(basename "$f")
  [ -f "$ROOT/scripts/$name" ] || continue # fleet-guard lives only in workflows/
  cmp -s "$f" "$ROOT/scripts/$name" || { echo "FAIL shared-scripts: ${f#"$ROOT"/} differs from scripts/$name"; bad=1; }
done
[ "$bad" = 0 ] && echo "ok shared-scripts"
exit $bad
