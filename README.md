# Fleet for Claude Code

Every Claude Code session becomes a **voyage** in your Fleet's ship's log, filed under its repo's **ship**. What you asked, what got committed, pushed, merged and deployed, and where things stand, all charted automatically. You can find any session later and pick it up with `claude --resume`.

It's almost invisible: Claude doesn't know it's part of a fleet. The hooks add nothing to Claude's context and never change how Claude talks or works; they only listen. The Fleet MCP tools and the `berths` skill are simply there for when a task needs them.

No binary to install: the hooks are small POSIX `sh` scripts that use only `curl`, `git`, `sed`, `awk` and `date`.

## Set sail in 2 minutes

1. **Sign in** at [fleet.osroc.io](https://fleet.osroc.io/app).
2. **Get a key** at [fleet.osroc.io/app/keys](https://fleet.osroc.io/app/keys). It starts with `fk_`.
3. **Run setup** with your key:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/osroc-labs/fleet-plugin/main/setup.sh | sh -s -- fk_your_key
   ```

   It saves the key to `~/.fleet/config.json` (readable only by you), adds `export FLEET_KEY=…` to your shell's rc file, and checks that the fleet answers.

   > While this repo is private, that raw URL won't work. Clone the repo and run `sh setup.sh fk_your_key` instead.

4. **In Claude Code**, add the plugin:

   ```
   /plugin marketplace add osroc-labs/fleet-plugin
   /plugin install fleet@osroc
   ```

That's it. Your next prompt starts a voyage.

**Sessions that were already open** sign on by themselves too. Closing the `/plugin` panel reloads plugins in that session, so its hooks start right away. If Claude Code asks first (a reload can cost one uncached request), run `/reload-plugins`. Other sessions you had open show "Plugins changed. Run /reload-plugins to activate"; run it, or just resume them later. Either way, the session registers on its next prompt or tool call, and its earlier prompts are backfilled into the log.

## What's aboard

- **Wayfinding hooks.** Each session registers on its first event and closes when it ends. Logged: your prompts, a one-line check-in after each turn (the start of Claude's reply), subagents' results as crew lines, `git commit` and `git push`, `gh pr merge`, deploys (wrangler, `npm`/`pnpm`/`yarn`/`bun run deploy`, eas, fly, netlify, firebase, `vercel --prod`), PR, issue and claude.ai artifact links, and "waiting on you" when Claude needs you.
- **The Fleet MCP tools**: voyages, the ship's log, the Captain's Post, and berths (iPhone, iPad and Apple TV simulators on your Fleet's Macs). Claude uses them only when you or a task call for them.
- **The `berths` skill**, which Claude loads only when it needs to see an app on an Apple device: how to lease a simulator, look, tap and release.
- **Commands:**
  - `/fleet:find <words>` finds past sessions and prints their `claude --resume` lines.
  - `/fleet:commission [vessel]` commissions this repo as a ship: carrier, battleship, destroyer, submarine, frigate, galleon, longship, junk, tugboat, canoe, raft or rubber duck.
  - `/fleet:join` boards the current session by hand. You shouldn't need it: the hooks register every session automatically. It's idempotent, so it's harmless if they already did.

## Privacy: what leaves your machine

**Fleet never talks to Claude; it only listens.** The hooks print nothing, add nothing to Claude's context and never ask Claude to check in. Everything below is captured from the outside.

- **Sent:** your prompts (redacted, up to 1,000 characters each; only what you typed: subagent hand-backs, task notifications, system reminders and other text Claude Code injects are cut, and a slash command is sent as `/command args`); the session's name (from `/rename`, else Claude Code's auto title); after each turn, the first 280 characters of Claude's final reply as the voyage's check-in (redacted), and the same for each subagent's final message; the artifact lines above; "waiting on you" notices; and once per session the repo's `origin` URL (credentials stripped), branch, commit sha, whether it's pushed, this machine's name and the session's folder.
- **Never sent:** transcripts, the rest of Claude's replies, tool output, file contents. The only exceptions are a commit's one-line subject and the PR, issue and artifact links found in a command's output.
- **Backfill:** when a session that was already running registers, the sender reads only your typed prompts from its local transcript (the last 50), redacts them and logs them. It's best effort: it skips tool results and anything that isn't a typed prompt, with the same filter as live prompts.
- **Redaction happens on your machine, before anything is sent.** It covers `sk-…` keys, Stripe keys, Fleet `fk_`/`fr_`/`fj_` keys, GitHub `ghp_`/`gho_`/`github_pat_` tokens, Slack `xox…` tokens, AWS access and secret keys, Google `AIza…` keys, JWTs, `Bearer …` values, `user:pass@` in URLs, `password=` values, PEM private keys, and `KEY=value` lines with secret-ish names (`*_KEY`, `*TOKEN*`, `*SECRET*`, `*PASSWORD*` and friends). It's pattern-based, so don't paste secrets anyway.
- **Where things live:** `~/.fleet/config.json` (your key), and `~/.fleet/wayfind/`: the queue waiting to send, session-to-voyage links, and `log` for any errors. Hooks never touch the network; a detached sender does, with retries.

## Strike the colors (uninstall)

```
/plugin uninstall fleet@osroc
/plugin marketplace remove osroc
```

Then, in a terminal:

```sh
rm -rf ~/.fleet/wayfind            # the local queue and session links
# Remove the "export FLEET_KEY=…  # Fleet (fleet-plugin)" line from your ~/.zshrc (or ~/.bash_profile, ~/.bashrc, ~/.profile).
# Keep ~/.fleet/config.json if you use the fleet CLI; otherwise: rm ~/.fleet/config.json
```

Revoke the key at [fleet.osroc.io/app/keys](https://fleet.osroc.io/app/keys).

## Troubleshooting

- **Nothing shows up?** Check `~/.fleet/wayfind/log`. With no key configured the plugin stays silent by design.
- **The MCP server says 401?** The key is wrong or revoked: make a new one and run setup again.
- **Using the fleet CLI's `fleet wayfind install` too?** Use one or the other, or every event is logged twice.
