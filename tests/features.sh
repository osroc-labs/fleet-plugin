#!/bin/sh
# Per-account features: the hooks stop when Sessions is off, and nothing above the account's level leaves the computer.
# The server's probe (GET /api/wayfind) says "sessions" and "sessionsLevel"; fleet-send keeps it in wayfind/features.
#   off: the hook queues nothing (and probes at most hourly); fleet-send drops what was queued and posts nothing.
#   activity: no prompt, reply or check-in text and no session name; commits and PR links still go.
#   presence: no commits or links either, no branch or commit in the session block.
# No network: a fake curl on PATH answers the probe from $PROBE and records every POST body.
# Run: sh tests/features.sh   (FLEET_SCRIPTS=<dir> tests another copy of the scripts). Needs node and git.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SCRIPTS=${FLEET_SCRIPTS:-$ROOT/scripts}
command -v node >/dev/null 2>&1 || { echo "features: needs node"; exit 2; }
T=$(mktemp -d "${TMPDIR:-/tmp}/fleet-features.XXXXXX")
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/cwd"
git -C "$T/cwd" init -q -b main && git -C "$T/cwd" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init

cat >"$T/bin/curl" <<'CURL'
#!/bin/sh
# Fake curl: GET answers the probe in $PROBE; a POST body is kept in $CAP and answered like the server.
cat >/dev/null
out="" data=""
while [ $# -gt 0 ]; do
  case "$1" in
  -o) out=$2; shift ;;
  --data-binary) data=${2#@}; shift ;;
  -K | -m | -w | -X | -A | -H) shift ;;
  *) ;;
  esac
  shift
done
if [ -z "$data" ]; then cp "$PROBE" "$out"; printf 200; exit 0; fi
n=$(ls "$CAP" | wc -l | tr -d ' ')
cp "$data" "$CAP/body.$n.json"
printf '{"voyageId":"vs_test"}' >"$out"; printf 201
CURL
chmod +x "$T/bin/curl"

SID=00000000-feat-4000-8000-000000000001
fails=0
fail() { echo "FAIL features: $*"; fails=$((fails + 1)); }

# A fresh ~/.fleet for scenario $1 with the probe answer $2; sets H, WF, CAP.
fresh() {
  H=$T/$1/home WF=$H/wayfind CAP=$T/$1/cap
  mkdir -p "$WF/queue" "$WF/state" "$WF/sessions" "$CAP"
  printf '%s' "$2" >"$T/$1/probe"
  printf 'vs_test\n' >"$WF/sessions/$SID"
  printf '%s\n' "$T/cwd" >"$WF/state/$SID.cwd"
  printf 'SECRET saved name' >"$WF/state/$SID.title"
  : >"$WF/state/$SID.opened"
}
send() { FLEET_HOME=$H FLEET_KEY=fk_testkey FLEET_SERVER=http://fleet.test CAP=$CAP PROBE=$T/$1/probe PATH="$T/bin:$PATH" sh "$SCRIPTS/fleet-send" </dev/null >/dev/null 2>&1; }
hook() { printf '%s' "$3" | FLEET_HOME=$H FLEET_KEY=fk_testkey FLEET_SERVER=http://fleet.test CAP=$CAP PROBE=$T/$1/probe PATH="$T/bin:$PATH" sh "$SCRIPTS/fleet-hook" "$2" >/dev/null 2>&1; }
queue() {
  cat >"$WF/queue/$SID.jsonl" <<'Q'
{"t":"at","at":"2026-10-15T10:00:00Z"}
{"t":"log","kind":"note","text":"Captain: SECRET prompt"}
{"t":"turn","crew":"","tp":"","raw":"SECRET reply"}
{"t":"turn","crew":"Explore@a1b2c3d4","tp":"","raw":"SECRET subagent"}
{"t":"log","kind":"note","text":"pr: https://github.com/osroc-labs/fleet/pull/7"}
{"t":"log","kind":"note","text":"commit abc1234 on main: ship it"}
{"t":"log","kind":"question","text":"Waiting on you: Claude needs your permission to use Bash"}
{"t":"close","reason":"exit"}
Q
}
PROMPT="{\"session_id\":\"$SID\",\"prompt\":\"SECRET typed prompt\",\"cwd\":\"$T/cwd\",\"transcript_path\":\"\"}"

# ---------- Sessions off ----------
fresh off '{"ok":true,"version":2,"replies":false,"sessions":false,"features":["simulators"],"sessionsLevel":"activity"}'
queue
send off
[ -z "$(ls "$CAP")" ] || fail "off: fleet-send posted $(ls "$CAP" | wc -l | tr -d ' ') batches"
[ -z "$(ls "$WF/queue" "$WF/work" 2>/dev/null | grep jsonl)" ] || fail "off: the queue wasn't dropped"
read -r _t _s on level <"$WF/features" || fail "off: no features file"
[ "${on:-}" = off ] && [ "${level:-}" = activity ] || fail "off: features file says '${on:-} ${level:-}'"
hook off UserPromptSubmit "$PROMPT"
[ ! -s "$WF/queue/$SID.jsonl" ] || fail "off: the hook queued $(cat "$WF/queue/$SID.jsonl")"
[ ! -f "$WF/probe.at" ] || fail "off: the hook probed though the answer is fresh"
# An hour later the hook starts one probe (and only one an hour); turning Sessions back on is seen.
printf '%s http://fleet.test off activity\n' "$(($(date +%s) - 4000))" >"$WF/features"
printf '{"ok":true,"replies":true,"sessions":true,"features":["sessions"],"sessionsLevel":"full"}' >"$T/off/probe"
hook off Stop "{\"session_id\":\"$SID\"}"
for _ in 1 2 3 4 5 6 7 8 9 10; do grep -q ' on full$' "$WF/features" 2>/dev/null && break; sleep 0.3; done
grep -q ' on full$' "$WF/features" || fail "off: the hourly probe didn't see Sessions back on: $(cat "$WF/features")"
[ -f "$WF/probe.at" ] || fail "off: no probe marker"

# ---------- Activity ----------
fresh activity '{"ok":true,"version":2,"replies":false,"sessions":true,"features":["sessions"],"sessionsLevel":"activity"}'
queue
send activity
hook activity UserPromptSubmit "$PROMPT"
grep -q SECRET "$WF/queue/$SID.jsonl" 2>/dev/null && fail "activity: the hook queued the prompt: $(cat "$WF/queue/$SID.jsonl")"
grep -q '{"t":"act"}' "$WF/queue/$SID.jsonl" 2>/dev/null || fail "activity: the hook didn't queue the activity"
ACT_CAP=$CAP

# ---------- Presence ----------
fresh presence '{"ok":true,"version":2,"replies":false,"sessions":true,"features":["sessions"],"sessionsLevel":"presence"}'
queue
send presence

# ---------- Full (as before) ----------
fresh full '{"ok":true,"version":2,"replies":true,"sessions":true,"features":["sessions"],"sessionsLevel":"full"}'
queue
send full

node - "$ACT_CAP" "$T/presence/cap" "$T/full/cap" <<'JS'
const fs = require("fs");
const read = (dir) => fs.readdirSync(dir).sort((a, b) => parseInt(a.split(".")[1]) - parseInt(b.split(".")[1])).map((f) => JSON.parse(fs.readFileSync(`${dir}/${f}`, "utf8")));
const fails = [];
const ok = (c, m) => { if (!c) fails.push(m); };
const [act, pres, full] = process.argv.slice(2).map(read);
const evs = (bodies) => bodies.flatMap((b) => b.events);
const kinds = (bodies) => evs(bodies).map((e) => e.kind).join(",");
ok(!/SECRET/.test(JSON.stringify(act)), `activity sent words: ${JSON.stringify(act)}`);
// (The hook's own prompt, sent after, adds one more activity.)
ok(kinds(act).startsWith("activity,activity,crew_end,artifact,artifact,waiting,end"), `activity kinds: ${kinds(act)}`);
ok(evs(act).find((e) => e.kind === "crew_end")?.data?.agentType === "Explore", "activity: the subagent's type is kept");
ok(/permission to use Bash/.test(JSON.stringify(act)), "activity keeps the wait's message");
ok(act.every((b) => !("title" in b.session) && b.session.branch === "main"), `activity session block: ${JSON.stringify(act[0].session)}`);
ok(!/SECRET|ship it|pull\/7|use Bash/.test(JSON.stringify(pres)), `presence sent more than presence: ${JSON.stringify(pres)}`);
ok(kinds(pres) === "activity,activity,crew_end,activity,activity,waiting,end", `presence kinds: ${kinds(pres)}`);
ok(pres.every((b) => !("branch" in b.session) && !("headSha" in b.session) && !("title" in b.session)), `presence session block: ${JSON.stringify(pres[0].session)}`);
ok(/SECRET prompt/.test(JSON.stringify(full)) && /SECRET reply/.test(JSON.stringify(full)), "full lost the words");
ok(evs(full).some((e) => e.kind === "prompt") && evs(full).some((e) => e.kind === "reply"), `full kinds: ${kinds(full)}`);
if (fails.length) { console.log("FAIL features\n- " + fails.join("\n- ")); process.exit(1); }
console.log(`ok features levels (activity ${evs(act).length}, presence ${evs(pres).length}, full ${evs(full).length} events)`);
JS
[ $? -eq 0 ] || fails=$((fails + 1))
[ "$fails" -eq 0 ] && echo "ok features" || exit 1
