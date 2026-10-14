#!/bin/sh
# Regression test: fleet-send always posts valid JSON (osroc-labs/fleet-plugin fix-send-json).
# The live failure: a subagent's crew_end event, built as "$(event … "{\"agentType\":…,\"agentId\":…}")", which macOS
# /bin/sh (bash 3.2) brace-expands into two arguments, so the batch read "data":"agentType":"claude" and the server
# answered 400 "body must be JSON" and the event was dropped. Also: one bad event (a bad escape in a queued line) is
# sent without the bad part instead of sinking its batch, and a bad saved session name never sinks a session.
# No network: a fake curl on PATH answers like the server (JSON.parse, 400 "body must be JSON" on a parse error).
# Run: sh tests/send-json.sh   (FLEET_SCRIPTS=<dir> tests another copy of the scripts). Needs node.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SCRIPTS=${FLEET_SCRIPTS:-$ROOT/scripts}
command -v node >/dev/null 2>&1 || { echo "send-json: needs node"; exit 2; }
T=$(mktemp -d "${TMPDIR:-/tmp}/fleet-send-json.XXXXXX")
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/cap" "$T/home/wayfind/queue" "$T/home/wayfind/state" "$T/home/wayfind/sessions" "$T/cwd"

cat >"$T/bin/curl" <<'CURL'
#!/bin/sh
# Fake curl: GET /api/wayfind says replies are on; a POST body is parsed with JSON.parse like the server does.
cat >/dev/null
out="" data="" url=""
while [ $# -gt 0 ]; do
  case "$1" in
  -o) out=$2; shift ;;
  --data-binary) data=${2#@}; shift ;;
  -K | -m | -w | -X | -A | -H) shift ;;
  -*) ;;
  *) url=$1 ;;
  esac
  shift
done
if [ -z "$data" ]; then printf '{"replies":true}' >"$out"; printf 200; exit 0; fi
n=$(ls "$CAP" | wc -l | tr -d ' ')
cp "$data" "$CAP/body.$n.json"
if node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$data" 2>/dev/null; then
  printf '{"voyageId":"vs_test"}' >"$out"; printf 201
else
  printf '{"error":"body must be JSON"}' >"$out"; printf 400
fi
CURL
chmod +x "$T/bin/curl"

SID=00000000-test-4000-8000-000000000001
WF=$T/home/wayfind
printf 'vs_test\n' >"$WF/sessions/$SID"
printf '%s\n' "$T/cwd" >"$WF/state/$SID.cwd"
printf 'a "broken\\ saved name' >"$WF/state/$SID.title"
cat >"$WF/queue/$SID.jsonl" <<'Q'
{"t":"at","at":"2026-10-14T20:00:00Z"}
{"t":"turn","crew":"general-purpose@a1b2c3d4","tp":"","raw":"Checked the logs"}
{"t":"log","kind":"note","text":"pr: https://github.com/osroc-labs/fleet/pull/1"}
{"t":"log","kind":"note","text":"commit abc1234: Fix it"}
{"t":"log","kind":"note","text":"a bad \q escape and a lone backslash \"}
{"t":"log","kind":"note","text":"after the bad one"}
{"t":"close","reason":"clear"}
Q

FLEET_HOME=$T/home FLEET_KEY=fk_testkey FLEET_SERVER=http://fleet.test CAP=$T/cap PATH="$T/bin:$PATH" \
  sh "$SCRIPTS/fleet-send" </dev/null >/dev/null 2>&1

node - "$T/cap" "$WF/log" <<'JS'
const fs = require("fs");
const [cap, logf] = process.argv.slice(2);
const log = fs.existsSync(logf) ? fs.readFileSync(logf, "utf8") : "";
const fails = [];
const ok = (cond, msg) => { if (!cond) fails.push(msg); };
const files = fs.readdirSync(cap).sort((a, b) => parseInt(a.split(".")[1]) - parseInt(b.split(".")[1]));
const events = [];
for (const f of files) {
  const s = fs.readFileSync(`${cap}/${f}`, "utf8");
  try {
    const b = JSON.parse(s);
    ok(b.session && b.session.machine, `${f}: session block without machine`);
    ok(!("title" in b.session), `${f}: the broken saved name was sent`);
    events.push(...b.events);
  } catch (e) {
    fails.push(`${f} isn't JSON (${e.message}): ${s.slice(0, 400)}`);
  }
}
ok(!/ 400 /.test(log), `the server refused a batch:\n${log}`);
const by = (pred) => events.find(pred);
const crew = by((e) => e.kind === "crew_end");
ok(crew && crew.data.agentType === "general-purpose" && crew.data.agentId === "a1b2c3d4", `crew_end data: ${JSON.stringify(crew)}`);
ok(crew && crew.at === "2026-10-14T20:00:00Z", `crew_end time: ${crew && crew.at}`);
const pr = by((e) => e.kind === "artifact" && e.data.type === "pr");
ok(pr && pr.data.url === "https://github.com/osroc-labs/fleet/pull/1", `pr artifact: ${JSON.stringify(pr)}`);
ok(by((e) => e.kind === "artifact" && e.data.type === "commit"), "commit artifact missing");
const badOp = `${"00000000-test-4000-8000-000000000001"}-5`;
ok(by((e) => e.opId === badOp), `the bad event (${badOp}) wasn't sent at all`);
ok(by((e) => e.kind === "log" && e.text === "after the bad one"), "the event after the bad one is missing");
ok(by((e) => e.kind === "end" && e.data.reason === "clear"), "end event missing");
ok(/isn't valid JSON at byte \d+/.test(log), `the bad event wasn't logged with its byte:\n${log}`);
ok(/session .*: block isn't valid JSON at byte \d+/.test(log), `the bad session name wasn't logged:\n${log}`);
if (fails.length) { console.log("FAIL send-json\n- " + fails.join("\n- ")); process.exit(1); }
console.log(`ok send-json (${files.length} requests, ${events.length} events)`);
if (process.env.VERBOSE) console.log(log);
JS
