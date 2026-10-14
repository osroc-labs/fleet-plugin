# Fleet for Claude Code

A tools-included toolkit for building with Claude Code, and for having fun with your friends while you do. Fleet gives Claude a set of clearly stated workflows that chain into each other (idea, prototype, build, the iPhone loop, verify, review, ship, triage), backed by your Fleet: **Prototypes** where you pick between options, an **Inbox** of what's waiting on you, **simulators** on your Macs, and a quiet log of every session you can search and resume.

Type `/fleet` to start. It shows the workflows, what's waiting on you, and suggests the right one for what you describe.

No binary to install: the hooks and helpers are small POSIX `sh` scripts that use only `curl`, `git`, `sed`, `awk` and `date`.

## The workflows

```
            /fleet:idea ─────────────┐
          (brain dump → issues)      │ clear enough to build
                 │ open-ended        │
                 ▼                   ▼
          /fleet:prototype ─pick─▶ /fleet:build ─iOS/Expo/RN─▶ /fleet:ios-loop
          ▲     │  (options in        │                              │
          └─────┘   Prototypes)       ▼                              │
       another round           /fleet:verify ◀──────────────────────┘
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
| `/fleet` | The front door: the workflows, what's waiting on you, and which one fits | the one it suggests |
| `/fleet:idea` | A brain dump becomes researched, scoped GitHub issues (existing ones merged, not duplicated) | prototype or build |
| `/fleet:prototype` | 2–4 genuinely different options as HTML pages or real simulator screenshots, published to Prototypes; waits for your pick (Build, Another round, Tuck away) | build the pick |
| `/fleet:build` | Builds a feature on its own branch with tests and a draft PR; hands iPhone work to the iOS loop | verify |
| `/fleet:ios-loop` | Leases a simulator, builds or installs the app (tunnels Metro when needed), smoke tests it with taps and screenshots, and puts it up for your review; iterates on Fix, solidifies on Ship it; `2` runs two tasks at once | verify, review, ship |
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

**Your repo comes first.** If a repo has its own skill for a step (its own `verify`, `deploy`, `review`…), Fleet uses that one. Fleet's workflows read the repo (its CLAUDE.md, scripts, `app.json`, `ios/`, CI and deploy config) to work out the commands, confirm them with you once, and save them in **`.fleet/workflow.json`**: test, build and deploy commands, gates, the iOS scheme and bundle id, preview and production URLs. It holds no secrets; commit it so your team shares it. `greenShips: true` there makes **Ship it** on a Fleet review your yes for production too; it's off unless you turn it on.

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

**Or by hand:** make a key at [fleet.osroc.io/app/keys](https://fleet.osroc.io/app/keys), then in Terminal run `curl -fsSL https://fleet.osroc.io/setup.sh | sh -s -- fk_your_key`. It saves the same `~/.fleet/config.json`, adds `export FLEET_KEY=…` to your shell's rc file, and checks that the fleet answers. Then the two `/plugin` lines; skip `/fleet:login`.

**Sessions that were already open** sign on by themselves too. Closing the `/plugin` panel reloads plugins in that session, so its hooks start right away. If Claude Code asks first (a reload can cost one uncached request), run `/reload-plugins`. Other sessions you had open show "Plugins changed. Run /reload-plugins to activate"; run it, or just resume them later. Either way, the session registers on its next prompt or tool call, and its earlier prompts are backfilled into the log.

## What's included

- **The workflow skills** above, plus the shared rules. Claude loads a workflow only when you run it or ask for what it does (options to pick, a review, a deploy); the descriptions say when. Nothing runs on its own, and Claude never starts Fleet tasks outside these workflows.
- **Session logging hooks.** Each session registers on its first event and closes when it ends. Logged: your prompts, a one-line check-in after each turn (the start of Claude's reply), subagents' results, `git commit` and `git push`, `gh pr merge`, deploys (wrangler, `npm`/`pnpm`/`yarn`/`bun run deploy`, eas, fly, netlify, firebase, `vercel --prod`), PR, issue and claude.ai artifact links, and "waiting on you" when Claude needs you. **The hooks only listen:** they print nothing and add nothing to Claude's context.
- **The Fleet MCP tools**: prototypes and reviews (`voyage_start` with `course: "prototype"`, `chart_options`, `await_decision`, `voyage_stage`), simulators on your Macs (`lease`, `boot`, `install_app`, `open_url`, `screenshot`, `tap`, `type_text`, `release`…), uploads (`upload_url`) and your session log. Claude uses them only inside a workflow or when you ask.
- **The `berths` skill**, which Claude loads only when it needs to see an app on an Apple device.
- **Helpers** in `scripts/`: `fleet-repo` (a read-only summary of the repo for the workflows) and `fleet-api` (read-only calls for the Inbox, search and status; the key never reaches Claude).
- `/fleet:join` says whether this session is logged. You shouldn't need it: the hooks register every session automatically.

## Privacy: what leaves your machine

**The hooks never talk to Claude; they only listen.** They print nothing, add nothing to Claude's context and never ask Claude to check in. Everything below is captured from the outside. The workflows send only what they publish on purpose: prototype pages and screenshots you'll review (kept 30 days), and the notes on them.

- **Sent:** your prompts (redacted, up to 1,000 characters each; only what you typed: subagent hand-backs, task notifications, system reminders and other text Claude Code injects are cut, and a slash command is sent as `/command args`); the session's name (from `/rename`); after each turn, the first 280 characters of Claude's final reply as the voyage's check-in (redacted), and the same for each subagent's final message; the artifact lines above; "waiting on you" notices; and, with each send, the session's details: the repo's `origin` URL (credentials stripped), branch, commit sha, whether it's pushed, this machine's name, the session's folder and its Claude Code config folder (which account).
- **Never sent:** transcripts, the rest of Claude's replies, tool output, file contents. The only exceptions are a commit's one-line subject and the PR, issue and artifact links found in a command's output.
- **Backfill:** when a session that was already running registers, the sender reads only your typed prompts from its local transcript (the last 50), redacts them and logs them. It's best effort: it skips tool results and anything that isn't a typed prompt, with the same filter as live prompts.
- **Redaction happens on your machine, before anything is sent.** It covers `sk-…` keys, Stripe keys, Fleet `fk_`/`fr_`/`fj_` keys, GitHub `ghp_`/`gho_`/`github_pat_` tokens, Slack `xox…` tokens, AWS access and secret keys, Google `AIza…` keys, JWTs, `Bearer …` values, `user:pass@` in URLs, `password=` values, PEM private keys, and `KEY=value` lines with secret-ish names (`*_KEY`, `*TOKEN*`, `*SECRET*`, `*PASSWORD*` and friends). It's pattern-based, so don't paste secrets anyway.
- **Where things live:** `~/.fleet/config.json` (your key; `/fleet:login` keeps a `login.pending` file next to it only while it waits), and `~/.fleet/wayfind/`: the queue waiting to send, session-to-voyage links, and `log` for any errors. Hooks never touch the network; a detached sender does, with retries.

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
