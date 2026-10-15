# Fleet for Claude Code

A tools-included toolkit for building with Claude Code, and for having fun with your friends while you do. At its heart is **`/fleet-workflows:loop`**: one perpetual build loop for a project that picks the next task, builds it, checks it, puts it in front of you, and ships it on your green, then does the next one. It conducts a set of clearly stated workflows (idea, prototype, build, verify, review, ship, triage) that also run on their own, backed by your Fleet: **Prototypes** where you pick between options, an **Inbox** of what's waiting on you, **simulators** on your Macs, and a quiet log of every session you can search and resume.

Fleet comes as plugins, one per feature, so Claude only carries what you use (see [Plugins and features](#plugins-and-features)): **`fleet`** (the session log, Fleet's tools and `/fleet:login`), **`fleet-sims`** (simulators on your Macs) and **`fleet-workflows`** (the loop and the workflow skills).

Type `/fleet:help` for a plain-words guide with examples, or `/fleet` (with fleet-workflows) to start. It shows the loop and the workflows, what's waiting on you, and suggests the right one for what you describe.

No binary to install: the hooks and helpers are small POSIX `sh` scripts that use only `curl`, `git`, `sed`, `awk` and `date`.

## The loop

```
/fleet-workflows:loop [mode] [lanes]          until you say stop, or the queue is empty

 ┌─▶ 1. pick the next task   your Fleet Inbox → GitHub issues → the roadmap
 │        │ open-ended?
 │        ├─────▶ 2. /fleet-workflows:prototype ┄┄ waits for your pick (the loop works on other tasks)
 │        ▼                  │ Build <option>
 │   3. /fleet-workflows:build ◀───────┴─────────────────────┐
 │        ▼                                        │
 │   4. /fleet-workflows:verify   the mode's quick check     │
 │        ▼                                        │
 │   5. /fleet-workflows:review   fresh eyes, fixes          │
 │        ▼                                        │
 │   6. up for your review in Fleet                │
 │      (test steps + screenshots or a preview)    │
 │        ▼                                        │
 │   7. your verdict ─────── Fix + notes ──────────┘ 8.
 │        │ Ship it
 │        ▼
 │      solidify (tests, every gate) ─▶ /fleet-workflows:ship (your yes, or Ship it with greenShips)
 └── 9. next task
```

| Mode | For | Its check before you look | What you review |
| --- | --- | --- | --- |
| `ios` | iOS, Expo and React Native apps | A smoke test on a leased simulator: taps and screenshots | Simulator screenshots; a phone preview when the repo has one |
| `web` | Sites and web apps | The changed flow's tests, then screenshots of the dev server or preview URL at phone and desktop width | Screenshots and the preview URL |
| `api` / `cli` | Servers and command-line tools | Tests, then `curl` or the commands themselves | The commands and their output |
| `prototype-only` | Deciding before building | None | Rounds of options; picks are recorded on the issue for a later build |

The mode is detected from the repo when you leave it out, and saved once confirmed. **`/fleet-workflows:loop 2`** (or `ios 2`) runs two tasks at once as separate agents, each with its own simulator, never more than your Macs have room for (`fleet_status`). Each task is tracked in Fleet (Inbox, Sessions, Prototypes), and the loop keeps a short journal on its session, so anyone on your Fleet can pick it up with `/fleet-workflows:loop resume`. Type **stop** and it finishes or parks the current step, releases every simulator, stops what it started and sums up. `/fleet-workflows:ios-loop` is `/fleet-workflows:loop ios`.

## The workflows

```
            /fleet-workflows:idea ─────────────┐
          (brain dump → issues)      │ clear enough to build
                 │ open-ended        │
                 ▼                   ▼
          /fleet-workflows:prototype ─pick─▶ /fleet-workflows:build
          ▲     │  (options in        │
          └─────┘   Prototypes)       ▼
       another round           /fleet-workflows:verify
                                      │ pass
  /fleet-workflows:triage ── fix ──────────────▶│
  ("it's broken")                     ▼
                               /fleet-workflows:review ── fixes on the branch
                                      │ clean
                                      ▼
                               /fleet-workflows:ship ── your yes ──▶ production ──▶ /fleet-workflows:verify
```

| Command | Does | Next |
| --- | --- | --- |
| `/fleet` | The front door: the loop, the workflows, what's waiting on you, and which one fits | the one it suggests |
| `/fleet-workflows:loop [mode] [n]` | Keeps building on the project: pick, prototype if open-ended, build, verify, review, your review, ship on green, next; modes `ios`, `web`, `api`, `cli`, `prototype-only`; `n` tasks at once | runs until you say stop |
| `/fleet-workflows:ios-loop` | Same as `/fleet-workflows:loop ios` | |
| `/fleet-workflows:idea` | A brain dump becomes researched, scoped GitHub issues (existing ones merged, not duplicated) | prototype or build |
| `/fleet-workflows:prototype` | 2–4 genuinely different options side by side on one page per topic (or real simulator screenshots), recommended one outlined, in about ten minutes; published to Prototypes, continuing an earlier round when there is one; waits for your pick (Build, Another round, Park, or Snooze until later) | build the pick |
| `/fleet-workflows:build` | Builds a feature on its own branch with tests and a draft PR; hands iPhone work to the loop's ios mode | verify |
| `/fleet-workflows:verify` | The repo's tests and gates plus a real look (a page or a simulator, with screenshots); on production, a signed-in read-only smoke check; known flakes tracked, not rerun blindly; pass or fail, never claimed unchecked | review |
| `/fleet-workflows:review` | An independent review (correctness, security, regressions, data cost, rollout), fixed on the branch; `round <sha>` checks just a fix round against what you asked for | ship |
| `/fleet-workflows:ship` | Merges and deploys with the repo's own deploy command or ordered release targets, **only with your yes**, guarded (right environment, native-build boundary, changelog entry), then verifies production | done |
| `/fleet-workflows:triage` | "It's broken": logs and errors first, the root cause with evidence, a fix with a regression test | verify |
| `/fleet-sims:sim` | A quick look at an app or page on an iPhone, iPad or Apple TV simulator; released when done | |
| `/fleet:status` | Your Macs and simulators, what's waiting on you, live sessions | |
| `/fleet:find <words>` | Searches every past session and prints the `claude --resume` line | |
| `/fleet:login` | Links this computer to your Fleet | |

Each workflow ends by naming the next step, and goes straight on when you've said to keep going ("build it and take it to review"). The rules they all share: verify before claiming anything works, never push to the main branch (branches and PRs only), production needs your explicit yes, every simulator lease is released and everything started is stopped (by PID or port, never a pattern kill), every branch works in its own git worktree so your checkout is never touched, Claude pushes back before making the common case worse to fix a rare one and never drops conflicting work, and a lasting preference you state is written into the repo (with the date and your words), not left in Claude's memory. Every agent gets a model and effort picked for its job, and every report ends the same way: **Callouts**, **Waiting on you**, **PR links** and **Options waiting on you**, each action with its link. The shared rules live in [`workflows/skills/fleet-workflows/SKILL.md`](workflows/skills/fleet-workflows/SKILL.md).

**Your repo comes first.** The loop (its queue, lanes and Inbox) always runs in Fleet, and each step runs your repo's skill for it when there is one: the one mapped in `skills` in `.fleet/workflow.json`, else a same-named skill (your own `verify`, `deploy`, `review`…), else Fleet's. Fleet's workflows read the repo (its CLAUDE.md, scripts, `app.json`, `ios/`, CI and deploy config) to work out the commands, confirm them with you once, and save them in **`.fleet/workflow.json`**: test, build and deploy commands, gates, the iOS scheme and bundle id, preview and production URLs. It holds no secrets; commit it so your team shares it. The loop reads its settings there too:

| Key | What it does |
| --- | --- |
| `loop.mode`, `loop.lanes`, `loop.maxLanes` | The mode, lanes to start with, and the most lanes allowed (default 3). |
| `loop.agentLimit` | Agents by the hour, e.g. `{ "beforeHour": 17, "tz": "America/Denver", "before": 2, "after": 5 }`: 2 before 5 PM Mountain, 5 after. |
| `loop.maxWaiting`, `loop.localSimulators` | Tasks waiting on your review before it stops starting more (3); simulators booted on this Mac (3). |
| `loop.firstSliceMinutes`, `loop.checkInMinutes` | A lane's first working slice reaches your review within 15 minutes; then it pushes and checks in every 10. |
| `preview` | What your preview build shows: `labelEnv` and `stepsEnv` name the build-time variables for the label (`Staging · branch · sha`) and the test steps still waiting on you; `ship.environmentCheck preview` proves it points at the review environment before you're told; `environment.protected` (on by default) means the review environment is never reset. Your app reads the two variables and shows them (a badge and a small "Testing now" panel). |
| `verdicts`, `feedback` | Commands that print green/red verdicts and tester feedback sent from your app, and mark them handled. Only `verdicts.owner` can ship or fix a task, and only for the build under review; testers' additions become `proposal` issues for your yes. |
| `board` | `{ "issue": 12, "marker": "fleet-board" }`: one status comment on that issue, edited in place on every move (on your device, building, shipping, next, shipped), that any session resumes from, with or without a Fleet key. |
| `issues.labels`, `issues.parent`, `issues.milestone`, `roadmap` | Where tasks come from: labeled issues (only an epic's sub-issues with `parent`), then the roadmap. |
| `skills` | Your skill for each step: `round` (one task's build, check and preview), `verify`, `review`, `ship`, `prototype`, `idea`, `triage`, e.g. `{ "round": "/ios-loop", "ship": "/deploy" }`. It's called with `from fleet-workflows:loop`, does one task, and returns. |
| `rules` | Your rules for the loop, one sentence each; it prints them at the start and follows them. |
| `prototype.kit`, `prototype.components`, `prototype.names` | What prototypes are drawn from: your prototype kit (tokens, fonts, common pieces, real art; copied into each round), how to open your component library (e.g. `pnpm storybook:build`) for today's screens, and the files whose labels options must use word for word. |
| `verify.smoke` | A signed-in, read-only check after a deploy: `{ "production": { "signIn", "checks", "envVars" }, "preview": … }`. `envVars` names the variables holding the smoke account's credentials; the values never leave them, and the account never writes. Maestro flows on a berth take the same names (`run_flow` `secrets`), filled in on the runner Mac from `fleet secrets set <owner/repo> <NAME>` (once per Mac). |
| `verify.absentInProduction` | Strings only a preview build shows (a badge, the staging host), checked absent from production. |
| `verify.quarantine` | Known flaky tests: `{ "tag": "@quarantine", "issueLabel": "flaky" }`. A quarantined failure is reported with its issue and doesn't fail the check; a new flake is rerun alone once, then tagged with an issue. |
| `ship.targets` | What a release deploys, in order, from one clean checkout: `[{ "name", "command", "check", "overTheAir" }]`, e.g. the server, then the over-the-air app update. A failed check stops the rest. `commands.deploy` is the one-target shorthand. |
| `ship.environmentCheck` | A command proving the built app calls production (or, given `preview`, not production). A failure stops the ship and runs `commands.restoreProduction` when set. |
| `ship.nativeCheck` | A command that fails when a change can't reach installed apps over the air; that change waits for a store build (`commands.storeBuild`) and your yes. |
| `ship.changelog` | `{ "path", "required": "user-visible", "clip" }`: a plain-words entry for anything people can see, plus a short clip for a new screen or flow when `clip` is set. |
| `replies` | `false` keeps Claude's replies out of the session log for this repo (prompts and the one-line check-in still go). See [Privacy](#privacy-what-leaves-your-machine). |
| `agents.models` | Model and effort per job for every agent, e.g. `{ "ui": ["opus", "high"], "small": ["sonnet", "medium"] }`. |
| `agents.enforceBriefs`, `agents.unpushedWork` | Opt-in hooks (off by default): refuse an agent brief with no model, effort, check-ins or stop; flag worktree commits sitting unpushed for over 10 minutes. |
| `report.sections` | Rename or reorder the closing report sections, e.g. `{ "waiting": "Waiting on you in staging" }`. |
| `worktreesOnly` | `true` (default): every branch in its own worktree; `false` lets a single task use a clean current checkout. |

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

   Then the ones for what you use: `/plugin install fleet-sims@osroc` (simulators) and `/plugin install fleet-workflows@osroc` (the loop and the workflow skills).

3. **Log in**, still in Claude Code:

   ```
   /fleet:login
   ```

   It shows a code like `SAIL-4821` and opens fleet.osroc.io/app/link in your browser. Check the code matches, tap **Link Claude Code**, and it prints "Signed in. New sessions will appear on your dashboard." The key is saved to `~/.fleet/config.json` (readable only by you); you never see or copy it. Do this once per computer.

That's it. Type `/fleet` to see the workflows (with fleet-workflows). Your sessions now show up on your dashboard. Until you log in, the session log stays silent, and the commands that need Fleet say "Run /fleet:login first."

**Or by hand:** make a key at [fleet.osroc.io/app/keys](https://fleet.osroc.io/app/keys), then in Terminal run `curl -fsSL https://fleet.osroc.io/setup.sh | sh -s -- fk_your_key`. It saves the same `~/.fleet/config.json`, adds `export FLEET_KEY=…` to your shell's rc file, and checks that the fleet answers. Then the two `/plugin` lines; skip `/fleet:login`.

**Sessions that were already open** sign on by themselves too. Closing the `/plugin` panel reloads plugins in that session, so its hooks start right away. If Claude Code asks first (a reload can cost one uncached request), run `/reload-plugins`. Other sessions you had open show "Plugins changed. Run /reload-plugins to activate"; run it, or just resume them later. Either way, the session registers on its next prompt or tool call, and its earlier prompts are backfilled into the log.

## Plugins and features

Fleet's features are switched per account in **Settings › Features** on the dashboard: **Sessions**, **Prototypes**, **Simulators** and **Workflows**. A feature that's off is off everywhere: its page is gone, its API refuses calls, Claude doesn't see its MCP tools (Claude Code reads them when a session starts), and with Sessions off the hooks stop and send nothing. A new account starts with nothing on; the plugin's first call turns everything on until you pick.

| Plugin | Brings | Feature |
| --- | --- | --- |
| `fleet` | The session log (hooks), Fleet's MCP tools, `/fleet:login`, `/fleet:status`, `/fleet:find`, `/fleet:join`, `/fleet:help` | Sessions; the tools of every feature that's on |
| `fleet-sims` | The `berths` skill and `/fleet-sims:sim` | Simulators |
| `fleet-workflows` | `/fleet-workflows:loop` and idea, prototype, build, verify, review, ship, triage, plus the two opt-in guards | Workflows (and Prototypes' skill) |

Skills can't be switched from the server, so they come with their plugin: install the ones you use. **Per repo**, Claude Code's own `enabledPlugins` turns a plugin off for one repo, for example a repo with its own workflow skills, in its `.claude/settings.json`:

```json
{ "enabledPlugins": { "fleet-workflows@osroc": false } }
```

## What's included

- **The loop and the workflow skills** above (fleet-workflows), plus the shared rules. Claude loads a workflow only when you run it or ask for what it does (options to pick, a review, a deploy); the descriptions say when. Nothing runs on its own, and Claude never starts Fleet tasks outside these workflows.
- **Session logging hooks.** Each session registers on its first event and closes when it ends. Logged: your prompts, Claude's reply to each (its text only, so the session reads like a conversation on your dashboard), a one-line check-in after each turn (the start of that reply), subagents' results, `git commit` and `git push`, `gh pr merge`, deploys (wrangler, `npm`/`pnpm`/`yarn`/`bun run deploy`, eas, fly, netlify, firebase, `vercel --prod`), PR, issue and claude.ai artifact links, and "waiting on you" when Claude needs you. **The hooks only listen:** they print nothing and add nothing to Claude's context. The one exception is two guards (in fleet-workflows) a repo can turn on in `.fleet/workflow.json` (`agents.enforceBriefs`, `agents.unpushedWork`): off by default, and on, they speak only to refuse an agent brief or flag unpushed work.
- **The Fleet MCP tools** (only those of the features that are on for your account): prototypes and reviews (`voyage_start` with `course: "prototype"`, `chart_options`, `await_decision`, `voyage_stage`), simulators on your Macs (`lease`, `boot`, `install_app`, `open_url`, `screenshot`, `tap`, `type_text`, `release`…), uploads (`upload_url`) and your session log. Claude uses them only inside a workflow or when you ask.
- **The `berths` skill** (fleet-sims), which Claude loads only when it needs to see an app on an Apple device.
- **Helpers** in `scripts/`: `fleet-repo` (a read-only summary of the repo for the workflows) and `fleet-api` (read-only calls for the Inbox, search and status; the key never reaches Claude).
- `/fleet:join` says whether this session is logged. You shouldn't need it: the hooks register every session automatically.

## Privacy: what leaves your machine

**The hooks never talk to Claude; they only listen** (except the two opt-in guards above, which send nothing anywhere). They print nothing, add nothing to Claude's context and never ask Claude to check in. Everything below is captured from the outside. The workflows send only what they publish on purpose: prototype pages and screenshots you'll review (kept until you delete the prototype; a share link you make shows one prototype, read-only, to anyone who has it, until you turn it off), and the notes on them.

- **How much is up to you:** Settings › Privacy on the dashboard sets what Sessions keeps. **Presence**: only that a session is running, on which computer and project, and when. **Activity** (new accounts): what happened (commits, pushes, PRs, deploys, links, waits), no prompts, replies, check-ins or session names. **Everything**: the list below. The sender asks the server hourly and sends no more than that; the server drops anything more anyway. With **Sessions off** the hooks queue nothing and send nothing (one probe an hour, so turning it back on is seen). Delete everything kept there with Delete session history.
- **Sent (Everything):** your prompts (redacted, up to 8,000 characters each, pasted text included; only what you typed: subagent hand-backs, task notifications, system reminders and other text Claude Code injects are cut, and a slash command is sent as `/command args`); the session's name (from `/rename`); after each turn, **Claude's reply** (redacted, up to 8 KB, text only: never its tool calls, tool output or thinking), the first 280 characters of it as the voyage's check-in, and the first 280 characters of each subagent's final message; the artifact lines above; "waiting on you" notices; and, with each send, the session's details: the repo's `origin` URL (credentials stripped), branch, commit sha, whether it's pushed, this machine's name, the session's folder and its Claude Code config folder (which account).
- **Never sent:** transcripts, Claude's tool calls and their output, its thinking, subagents' work beyond that one line, file contents. The only exceptions are a commit's one-line subject and the PR, issue and artifact links found in a command's output.
- **Each message keeps its own time.** Prompts and check-ins carry the moment the hook saw them, even if the send waits for the network; backfilled ones and replies carry their time from the transcript.
- **Backfill:** when a session that was already running registers, the sender reads its local transcript and logs the last 50 turns: your typed prompts and Claude's replies (text only), each redacted and at its transcript time. It's best effort: it skips tool calls, tool results, thinking and anything that isn't a typed prompt, with the same filter as live prompts.
- **Turning replies off:** add `"replies": false` to `~/.fleet/config.json` (every repo on this machine) or to a repo's `.fleet/workflow.json` (that repo, for everyone who works in it). Prompts and the 280-character check-in are still logged. Replies are also only sent to a Fleet server that says it takes them; an older one gets the check-in alone.
- **Redaction happens on your machine, before anything is sent.** It covers `sk-…` keys, Stripe keys, Fleet `fk_`/`fr_`/`fj_` keys, GitHub `ghp_`/`gho_`/`github_pat_` tokens, Slack `xox…` tokens, AWS access and secret keys, Google `AIza…` keys, JWTs, `Bearer …` values, `user:pass@` in URLs, `password=` values, PEM private keys, and `KEY=value` lines with secret-ish names (`*_KEY`, `*TOKEN*`, `*SECRET*`, `*PASSWORD*` and friends). It's pattern-based, so don't paste secrets anyway.
- **Where things live:** `~/.fleet/config.json` (your key; `/fleet:login` keeps a `login.pending` file next to it only while it waits), and `~/.fleet/wayfind/`: the queue waiting to send, session-to-voyage links, `caps` and `features` (whether your Fleet server takes replies, whether Sessions is on and how much it keeps; checked hourly), and `log` for any errors. Hooks never touch the network; a detached sender does, with retries.

## Uninstall

```
/plugin uninstall fleet-workflows@osroc
/plugin uninstall fleet-sims@osroc
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

**Had Fleet Social?** `fleet-social` is retired (its sign-in and presence get "Fleet Social is retired" from the server). Uninstall it with `/plugin uninstall fleet-social@osroc`, then `rm -rf ~/.fleet/social`. Its key in `~/.fleet/config.json` keeps working for the `fleet` plugin.

## Troubleshooting

- **`/fleet` doesn't open the menu?** Use `/fleet-workflows:fleet`; the short form works unless another plugin or skill is also named `fleet`.
- **Nothing shows up?** Run `/fleet:login` if you haven't; with no key the plugin stays silent by design. Is Sessions on in Settings › Features? Otherwise check `~/.fleet/wayfind/log`.
- **A Fleet tool is missing, or says "… is off for this account"?** Turn its feature on in Settings › Features, then start a new session (Claude Code reads the tools at the start).
- **`/fleet:loop`, `/fleet:prototype` or `/fleet:sim` not found?** They moved: `/plugin install fleet-workflows@osroc` (`/fleet-workflows:loop` …) and `/plugin install fleet-sims@osroc` (`/fleet-sims:sim`).
- **The MCP server says 401?** The key is wrong or revoked: run `/fleet:login` again. Right after a login, the Fleet tools connect in new sessions; in an open one, run `/mcp` and reconnect fleet.
- **`/fleet:login` says it isn't available yet?** Your Fleet server predates device login: use the by-hand setup above.
- **No browser on this machine (SSH)?** `/fleet:login` prints the link and code; open the link on any device where you're signed in.
- **`install_app` says "This is a device build"?** Berths run simulator builds only; an `.ipa` is for phones. Use an EAS profile with `"ios": { "simulator": true }`, or `fleet build-sim --profile preview --lease <id>` in an Expo project.
- **`run_flow` says a secret isn't set?** On the Mac it names, run `fleet secrets set <owner/repo> <NAME>` (it asks for the value, hidden), or `fleet secrets import <owner/repo> <path to .env> <NAME>...`. `fleet secrets list <owner/repo>` shows the names saved. Older runners need `fleet runner update` first.
- **Using the fleet CLI's `fleet wayfind install` too?** Use one or the other, or every event is logged twice.
