# Fleet for Claude Code

Every Claude Code session becomes a **voyage** in your Fleet's ship's log, filed under its repo's **ship**. What you asked, what got committed, pushed, merged and deployed, and where things stand, all charted automatically. You can find any session later and pick it up with `claude --resume`.

It's almost invisible: Claude doesn't know it's part of a fleet. The hooks add nothing to Claude's context and never change how Claude talks or works; they only listen. The Fleet MCP tools and the `berths` skill are simply there for when a task needs them.

No binary to install: the hooks are small POSIX `sh` scripts that use only `curl`, `git`, `sed`, `awk` and `date`.

## Set sail in 2 minutes

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

That's it. Your next prompt starts a voyage. Until you log in, the plugin stays silent, and `/fleet:find` and `/fleet:commission` say "Run /fleet:login first."

**Or by hand:** make a key at [fleet.osroc.io/app/keys](https://fleet.osroc.io/app/keys), then in Terminal run `curl -fsSL https://fleet.osroc.io/setup.sh | sh -s -- fk_your_key`. It saves the same `~/.fleet/config.json`, adds `export FLEET_KEY=…` to your shell's rc file, and checks that the fleet answers. Then the two `/plugin` lines; skip `/fleet:login`.

**Sessions that were already open** sign on by themselves too. Closing the `/plugin` panel reloads plugins in that session, so its hooks start right away. If Claude Code asks first (a reload can cost one uncached request), run `/reload-plugins`. Other sessions you had open show "Plugins changed. Run /reload-plugins to activate"; run it, or just resume them later. Either way, the session registers on its next prompt or tool call, and its earlier prompts are backfilled into the log.

## What's aboard

- **Wayfinding hooks.** Each session registers on its first event and closes when it ends. Logged: your prompts, a one-line check-in after each turn (the start of Claude's reply), subagents' results as crew lines, `git commit` and `git push`, `gh pr merge`, deploys (wrangler, `npm`/`pnpm`/`yarn`/`bun run deploy`, eas, fly, netlify, firebase, `vercel --prod`), PR, issue and claude.ai artifact links, and "waiting on you" when Claude needs you.
- **The Fleet MCP tools**: voyages, the ship's log, the Captain's Post, and berths (iPhone, iPad and Apple TV simulators on your Fleet's Macs). Claude uses them only when you or a task call for them.
- **The `berths` skill**, which Claude loads only when it needs to see an app on an Apple device: how to lease a simulator, look, tap and release.
- **Commands:**
  - `/fleet:login` signs this computer in to your Fleet (see above). Run it again to switch fleets or replace a revoked key.
  - `/fleet:find <words>` finds past sessions and prints their `claude --resume` lines.
  - `/fleet:commission [vessel]` commissions this repo as a ship: carrier, battleship, destroyer, submarine, frigate, galleon, longship, junk, tugboat, hydrofoil, catamaran, speedboat, jet ski, canoe, raft or rubber duck.
  - `/fleet:join` says whether this session is logged and as which voyage. You shouldn't need it: the hooks register every session automatically.

## Privacy: what leaves your machine

**Fleet never talks to Claude; it only listens.** The hooks print nothing, add nothing to Claude's context and never ask Claude to check in. Everything below is captured from the outside.

- **Sent:** your prompts (redacted, up to 1,000 characters each; only what you typed: subagent hand-backs, task notifications, system reminders and other text Claude Code injects are cut, and a slash command is sent as `/command args`); the session's name (from `/rename`); after each turn, the first 280 characters of Claude's final reply as the voyage's check-in (redacted), and the same for each subagent's final message; the artifact lines above; "waiting on you" notices; and, with each send, the session's details: the repo's `origin` URL (credentials stripped), branch, commit sha, whether it's pushed, this machine's name, the session's folder and its Claude Code config folder (which account).
- **Never sent:** transcripts, the rest of Claude's replies, tool output, file contents. The only exceptions are a commit's one-line subject and the PR, issue and artifact links found in a command's output.
- **Backfill:** when a session that was already running registers, the sender reads only your typed prompts from its local transcript (the last 50), redacts them and logs them. It's best effort: it skips tool results and anything that isn't a typed prompt, with the same filter as live prompts.
- **Redaction happens on your machine, before anything is sent.** It covers `sk-…` keys, Stripe keys, Fleet `fk_`/`fr_`/`fj_` keys, GitHub `ghp_`/`gho_`/`github_pat_` tokens, Slack `xox…` tokens, AWS access and secret keys, Google `AIza…` keys, JWTs, `Bearer …` values, `user:pass@` in URLs, `password=` values, PEM private keys, and `KEY=value` lines with secret-ish names (`*_KEY`, `*TOKEN*`, `*SECRET*`, `*PASSWORD*` and friends). It's pattern-based, so don't paste secrets anyway.
- **Where things live:** `~/.fleet/config.json` (your key; `/fleet:login` keeps a `login.pending` file next to it only while it waits), and `~/.fleet/wayfind/`: the queue waiting to send, session-to-voyage links, and `log` for any errors. Hooks never touch the network; a detached sender does, with retries.

## Strike the colors (uninstall)

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

- **Nothing shows up?** Run `/fleet:login` if you haven't; with no key the plugin stays silent by design. Otherwise check `~/.fleet/wayfind/log`.
- **The MCP server says 401?** The key is wrong or revoked: run `/fleet:login` again. Right after a login, the Fleet tools connect in new sessions; in an open one, run `/mcp` and reconnect fleet.
- **`/fleet:login` says it isn't available yet?** Your Fleet server predates device login: use the by-hand setup above.
- **No browser on this machine (SSH)?** `/fleet:login` prints the link and code; open the link on any device where you're signed in.
- **Using the fleet CLI's `fleet wayfind install` too?** Use one or the other, or every event is logged twice.
