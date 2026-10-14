# Fleet for Claude Code

A tools-included toolkit for building with Claude Code, and for having fun with your friends while you do. At its heart is **`/fleet:loop`**: one perpetual build loop for a project that picks the next task, builds it, checks it, puts it in front of you, and ships it on your green, then does the next one. It conducts a set of clearly stated workflows (idea, prototype, build, verify, review, ship, triage) that also run on their own, backed by your Fleet: **Prototypes** where you pick between options, an **Inbox** of what's waiting on you, **simulators** on your Macs, and a quiet log of every session you can search and resume.

Type `/fleet:help` for a plain-words guide with examples, or `/fleet` to start. It shows the loop and the workflows, what's waiting on you, and suggests the right one for what you describe.

No binary to install: the hooks and helpers are small POSIX `sh` scripts that use only `curl`, `git`, `sed`, `awk` and `date`.

## The loop

```
/fleet:loop [mode] [lanes]          until you say stop, or the queue is empty

 ┌─▶ 1. pick the next task   your Fleet Inbox and orders → GitHub issues → the roadmap
 │        │ open-ended?
 │        ├─────▶ 2. /fleet:prototype ┄┄ waits for your pick (the loop works on other tasks)
 │        ▼                  │ Build <option>
 │   3. /fleet:build ◀───────┴─────────────────────┐
 │        ▼                                        │
 │   4. /fleet:verify   the mode's quick check     │
 │        ▼                                        │
 │   5. /fleet:review   fresh eyes, fixes          │
 │        ▼                                        │
 │   6. up for your review in Fleet                │
 │      (test steps + screenshots or a preview)    │
 │        ▼                                        │
 │   7. your verdict ─────── Fix + notes ──────────┘ 8.
 │        │ Ship it
 │        ▼
 │      solidify (tests, every gate) ─▶ /fleet:ship (your yes, or Ship it with greenShips)
 └── 9. next task
```

| Mode | For | Its check before you look | What you review |
| --- | --- | --- | --- |
| `ios` | iOS, Expo and React Native apps | A smoke test on a leased simulator: taps and screenshots | Simulator screenshots; a phone preview when the repo has one |
| `web` | Sites and web apps | The changed flow's tests, then screenshots of the dev server or preview URL at phone and desktop width | Screenshots and the preview URL |
| `api` / `cli` | Servers and command-line tools | Tests, then `curl` or the commands themselves | The commands and their output |
| `prototype-only` | Deciding before building | None | Rounds of options; picks are recorded on the issue for a later build |

The mode is detected from the repo when you leave it out, and saved once confirmed. **`/fleet:loop 2`** (or `ios 2`) runs two tasks at once as separate agents, each with its own simulator, never more than your Macs have room for (`fleet_status`). Each task is tracked in Fleet (Inbox, Sessions, Prototypes), and the loop keeps a short journal on its session, so anyone on your Fleet can pick it up with `/fleet:loop resume`. Type **stop** and it finishes or parks the current step, releases every simulator, stops what it started and sums up. `/fleet:ios-loop` is `/fleet:loop ios`.

## The workflows

```
            /fleet:idea ─────────────┐
          (brain dump → issues)      │ clear enough to build
                 │ open-ended        │
                 ▼                   ▼
          /fleet:prototype ─pick─▶ /fleet:build
          ▲     │  (options in        │
          └─────┘   Prototypes)       ▼
       another round           /fleet:verify
                                      │ pass
  /fleet:triage ── fix ──────────────▶│
  ("it's broken")                     ▼
                               /fleet:review ── fixes on the branch
                                      │ clean
                                      ▼
                               /fleet:ship ── your yes ──▶ production ──▶ /fleet:verify
```

| Command | Does | Next |
| --- | --- | --- |
| `/fleet` | The front door: the loop, the workflows, what's waiting on you, and which one fits | the one it suggests |
| `/fleet:loop [mode] [n]` | Keeps building on the project: pick, prototype if open-ended, build, verify, review, your review, ship on green, next; modes `ios`, `web`, `api`, `cli`, `prototype-only`; `n` tasks at once | runs until you say stop |
| `/fleet:ios-loop` | Same as `/fleet:loop ios` | |
| `/fleet:idea` | A brain dump becomes researched, scoped GitHub issues (existing ones merged, not duplicated) | prototype or build |
| `/fleet:prototype` | 2–4 genuinely different options as HTML pages or real simulator screenshots, published to Prototypes; waits for your pick (Build, Another round, Tuck away) | build the pick |
| `/fleet:build` | Builds a feature on its own branch with tests and a draft PR; hands iPhone work to the loop's ios mode | verify |
| `/fleet:verify` | The repo's tests and gates plus a real look (a page or a simulator, with screenshots); pass or fail, never claimed unchecked | review |
| `/fleet:review` | An independent review (correctness, security, regressions, data cost, rollout), fixed on the branch | ship |
| `/fleet:ship` | Merges and deploys with the repo's own deploy command, **only with your yes**, then verifies production | done |
| `/fleet:triage` | "It's broken": logs and errors first, the root cause with evidence, a fix with a regression test | verify |
| `/fleet:sim` | A quick look at an app or page on an iPhone, iPad or Apple TV simulator; released when done | |
| `/fleet:status` | Your Macs and simulators, what's waiting on you, live sessions | |
| `/fleet:find <words>` | Searches every past session and prints the `claude --resume` line | |
| `/fleet:login` | Links this computer to your Fleet | |
| `/fleet:commission [vessel]` | Gives this repo a boat on your Fleet's sea | |

Each workflow ends by naming the next step, and goes straight on when you've said to keep going ("build it and take it to review"). The rules they all share: verify before claiming anything works, never push to the main branch (branches and PRs only), production needs your explicit yes, every simulator lease is released and everything started is stopped, and updates stay brief. The shared rules live in [`skills/fleet-workflows/SKILL.md`](skills/fleet-workflows/SKILL.md).

**Your repo comes first.** The loop (its queue, lanes and Inbox) always runs in Fleet, and each step runs your repo's skill for it when there is one: the one mapped in `skills` in `.fleet/workflow.json`, else a same-named skill (your own `verify`, `deploy`, `review`…), else Fleet's. Fleet's workflows read the repo (its CLAUDE.md, scripts, `app.json`, `ios/`, CI and deploy config) to work out the commands, confirm them with you once, and save them in **`.fleet/workflow.json`**: test, build and deploy commands, gates, the iOS scheme and bundle id, preview and production URLs. It holds no secrets; commit it so your team shares it. The loop reads its settings there too:

| Key | What it does |
| --- | --- |
| `loop.mode`, `loop.lanes`, `loop.maxLanes` | The mode, lanes to start with, and the most lanes allowed (default 3). |
| `loop.agentLimit` | Agents by the hour, e.g. `{ "beforeHour": 17, "tz": "America/Denver", "before": 2, "after": 5 }`: 2 before 5 PM Mountain, 5 after. |
| `loop.maxWaiting`, `loop.localSimulators` | Tasks waiting on your review before it stops starting more (3); simulators booted on this Mac (3). |
| `issues.labels`, `issues.parent`, `issues.milestone`, `roadmap` | Where tasks come from: labeled issues (only an epic's sub-issues with `parent`), then the roadmap. |
| `skills` | Your skill for each step: `round` (one task's build, check and preview), `verify`, `review`, `ship`, `prototype`, `idea`, `triage`, e.g. `{ "round": "/ios-loop", "ship": "/deploy" }`. It's called with `from fleet:loop`, does one task, and returns. |
| `rules` | Your rules for the loop, one sentence each; it prints them at the start and follows them. |
| `replies` | `false` keeps Claude's replies out of the session log for this repo (prompts and the one-line check-in still go). See [Privacy](#privacy-what-leaves-your-machine). |

`greenShips: true` there makes **Ship it** on a Fleet review your yes for production too, so the loop ships each task on your green; it's off unless you turn it on.

**No Fleet account?** The workflows still run: options stay as local files, simulators are local and headless, and decisions happen in chat.

## Install in 2 minutes

No terminal needed.

1. **Sign in** at [fleet.osroc.io](https://fleet.osroc.io/app) with Google, or open the invite link a friend sent you.
2. **In Claude Code**, add the plugin, one line at a time:

   ```
   /plugin marketplace add osroc-labs/fleet-plugin
   /plugin install fleet@osroc
   ```

3. **Log in**, still in Claude Code:

   ```
   /fleet:login
   ```

   It shows a code like `SAIL-4821` and opens fleet.osroc.io/app/link in your browser. Check the code matches, tap **Link Claude Code**, and it prints "Signed in. New sessions will appear on your dashboard." The key is saved to `~/.fleet/config.json` (readable only by you); you never see or copy it. Do this once per computer.

That's it. Type `/fleet` to see the workflows. Your sessions now show up on your dashboard. Until you log in, the session log stays silent, and the commands that need Fleet say "Run /fleet:login first."

**Just want to hang out with friends?** See [Fleet Social](#fleet-social-just-hang-out): presence only, no toolkit.

**Or by hand:** make a key at [fleet.osroc.io/app/keys](https://fleet.osroc.io/app/keys), then in Terminal run `curl -fsSL https://fleet.osroc.io/setup.sh | sh -s -- fk_your_key`. It saves the same `~/.fleet/config.json`, adds `export FLEET_KEY=…` to your shell's rc file, and checks that the fleet answers. Then the two `/plugin` lines; skip `/fleet:login`.

**Sessions that were already open** sign on by themselves too. Closing the `/plugin` panel reloads plugins in that session, so its hooks start right away. If Claude Code asks first (a reload can cost one uncached request), run `/reload-plugins`. Other sessions you had open show "Plugins changed. Run /reload-plugins to activate"; run it, or just resume them later. Either way, the session registers on its next prompt or tool call, and its earlier prompts are backfilled into the log.

## What's included

- **The loop and the workflow skills** above, plus the shared rules. Claude loads a workflow only when you run it or ask for what it does (options to pick, a review, a deploy); the descriptions say when. Nothing runs on its own, and Claude never starts Fleet tasks outside these workflows.
- **Session logging hooks.** Each session registers on its first event and closes when it ends. Logged: your prompts, Claude's reply to each (its text only, so the session reads like a conversation on your dashboard), a one-line check-in after each turn (the start of that reply), subagents' results, `git commit` and `git push`, `gh pr merge`, deploys (wrangler, `npm`/`pnpm`/`yarn`/`bun run deploy`, eas, fly, netlify, firebase, `vercel --prod`), PR, issue and claude.ai artifact links, and "waiting on you" when Claude needs you. **The hooks only listen:** they print nothing and add nothing to Claude's context.
- **The Fleet MCP tools**: prototypes and reviews (`voyage_start` with `course: "prototype"`, `chart_options`, `await_decision`, `voyage_stage`), simulators on your Macs (`lease`, `boot`, `install_app`, `open_url`, `screenshot`, `tap`, `type_text`, `release`…), uploads (`upload_url`) and your session log. Claude uses them only inside a workflow or when you ask.
- **The `berths` skill**, which Claude loads only when it needs to see an app on an Apple device.
- **Helpers** in `scripts/`: `fleet-repo` (a read-only summary of the repo for the workflows) and `fleet-api` (read-only calls for the Inbox, search and status; the key never reaches Claude).
- `/fleet:join` says whether this session is logged. You shouldn't need it: the hooks register every session automatically.

## Privacy: what leaves your machine

**The hooks never talk to Claude; they only listen.** They print nothing, add nothing to Claude's context and never ask Claude to check in. Everything below is captured from the outside. The workflows send only what they publish on purpose: prototype pages and screenshots you'll review (kept 30 days), and the notes on them.

- **Sent:** your prompts (redacted, up to 8,000 characters each, pasted text included; only what you typed: subagent hand-backs, task notifications, system reminders and other text Claude Code injects are cut, and a slash command is sent as `/command args`); the session's name (from `/rename`); after each turn, **Claude's reply** (redacted, up to 8 KB, text only: never its tool calls, tool output or thinking), the first 280 characters of it as the voyage's check-in, and the first 280 characters of each subagent's final message; the artifact lines above; "waiting on you" notices; and, with each send, the session's details: the repo's `origin` URL (credentials stripped), branch, commit sha, whether it's pushed, this machine's name, the session's folder and its Claude Code config folder (which account).
- **Never sent:** transcripts, Claude's tool calls and their output, its thinking, subagents' work beyond that one line, file contents. The only exceptions are a commit's one-line subject and the PR, issue and artifact links found in a command's output.
- **Each message keeps its own time.** Prompts and check-ins carry the moment the hook saw them, even if the send waits for the network; backfilled ones and replies carry their time from the transcript.
- **Backfill:** when a session that was already running registers, the sender reads its local transcript and logs the last 50 turns: your typed prompts and Claude's replies (text only), each redacted and at its transcript time. It's best effort: it skips tool calls, tool results, thinking and anything that isn't a typed prompt, with the same filter as live prompts.
- **Turning replies off:** add `"replies": false` to `~/.fleet/config.json` (every repo on this machine) or to a repo's `.fleet/workflow.json` (that repo, for everyone who works in it). Prompts and the 280-character check-in are still logged. Replies are also only sent to a Fleet server that says it takes them; an older one gets the check-in alone.
- **Redaction happens on your machine, before anything is sent.** It covers `sk-…` keys, Stripe keys, Fleet `fk_`/`fr_`/`fj_` keys, GitHub `ghp_`/`gho_`/`github_pat_` tokens, Slack `xox…` tokens, AWS access and secret keys, Google `AIza…` keys, JWTs, `Bearer …` values, `user:pass@` in URLs, `password=` values, PEM private keys, and `KEY=value` lines with secret-ish names (`*_KEY`, `*TOKEN*`, `*SECRET*`, `*PASSWORD*` and friends). It's pattern-based, so don't paste secrets anyway.
- **Where things live:** `~/.fleet/config.json` (your key; `/fleet:login` keeps a `login.pending` file next to it only while it waits), and `~/.fleet/wayfind/`: the queue waiting to send, session-to-voyage links, `caps` (whether your Fleet server takes replies, checked hourly), and `log` for any errors. Hooks never touch the network; a detached sender does, with retries.

## Fleet Social: just hang out

Want the social side (your boat in World next to your friends', moving while you work) without the toolkit? Install **`fleet-social`** instead. It's a separate, tiny plugin in the same marketplace: four presence hooks and a login command. No MCP server, no skills, no binary, and nothing ever printed into Claude's context.

**Install**, in Claude Code (sign in at [fleet.osroc.io](https://fleet.osroc.io/app) first, or open the invite link a friend sent you):

```
/plugin marketplace add osroc-labs/fleet-plugin
/plugin install fleet-social@osroc
/fleet-social:login
```

`/fleet-social:login` works like `/fleet:login`: a code, a page to approve it, and the key saved to `~/.fleet/config.json`. Your dashboard then shows World, Friends and Settings.

**What's sent**, to `POST /api/social/presence`, about once a minute while you work plus right away when a session starts or ends:

| Field | What it is |
| --- | --- |
| `project` | The project's display name: the repo's folder name (the main checkout's, for a worktree), else the folder's. Never a path, never `owner/repo`. Friends don't see it either: they see your boat, and a name only if you rename the project yourself. |
| `state` | `active` (you just sent a prompt), `idle` (Claude finished; waiting for you) or `ended` (no session left open on this computer) |
| `mood` | Optional: a number from −2 to 2, the average of the session's last few prompt scores. The score is worked out on your computer from what you typed (frustrated or delighted phrases, swearing, capitals: the same heuristic as the Fleet CLI). Turn it off with `"mood": "off"` in `~/.fleet/config.json` or `FLEET_SOCIAL_MOOD=off`. |

**What's never sent:** your prompts, Claude's replies, code, file names, paths, branch names, the repo's remote, transcripts or logs. The hook reads a prompt into memory only to score it, and keeps just the number. On disk, Fleet Social keeps one small file per open session in `~/.fleet/social/sessions/` (the project's name, active or idle, the time, the scores), what it last sent, and a `log` for errors.

**Quiet by design.** The hooks never touch the network (a detached sender does), never print and always exit 0. With no key they do nothing. If your Fleet server doesn't know Fleet Social yet, the sender rests for an hour and tries again later.

**Upgrading to the full toolkit:** `/plugin install fleet@osroc`. It uses the same key: same account, same friends, same boat, and your dashboard switches to the full view on its own the first time the full plugin checks in (or switch it yourself in Settings › Account). Fleet Social then goes quiet for every session the full plugin reports, so nothing is counted twice; uninstall it when you like with `/plugin uninstall fleet-social@osroc` and `rm -rf ~/.fleet/social`.

## Uninstall

```
/plugin uninstall fleet@osroc
/plugin marketplace remove osroc
```

Then, in a terminal:

```sh
rm -rf ~/.fleet/wayfind            # the local queue and session links
# If you used setup.sh: remove the "export FLEET_KEY=…  # Fleet (fleet-plugin)" line from your ~/.zshrc (or ~/.bash_profile, ~/.bashrc, ~/.profile).
# Keep ~/.fleet/config.json if you use the fleet CLI; otherwise: rm ~/.fleet/config.json
```

Revoke the key at [fleet.osroc.io/app/keys](https://fleet.osroc.io/app/keys).

## Troubleshooting

- **`/fleet` doesn't open the menu?** Use `/fleet:fleet`; the short form works unless another plugin or skill is also named `fleet`.
- **Nothing shows up?** Run `/fleet:login` if you haven't; with no key the plugin stays silent by design. Otherwise check `~/.fleet/wayfind/log`.
- **The MCP server says 401?** The key is wrong or revoked: run `/fleet:login` again. Right after a login, the Fleet tools connect in new sessions; in an open one, run `/mcp` and reconnect fleet.
- **`/fleet:login` says it isn't available yet?** Your Fleet server predates device login: use the by-hand setup above.
- **No browser on this machine (SSH)?** `/fleet:login` prints the link and code; open the link on any device where you're signed in.
- **Using the fleet CLI's `fleet wayfind install` too?** Use one or the other, or every event is logged twice.
