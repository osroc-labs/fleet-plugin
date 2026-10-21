# Fleet for Claude Code

Simulator and emulator berths for agents. Fleet turns the Macs you already own into iPhone, iPad, Apple TV simulators and Android emulators that Claude leases, drives and hands back: it puts your app on a real device, looks at it, taps through it, runs your Maestro flows, checks which over-the-air update is running, and releases the berth when it's done. Every step runs on the Mac that holds the berth, never on the machine you're typing on. Around the devices is the Expo tooling: simulator builds, update checks, and a dev client reached through a tunnel.

One plugin, **`fleet@osroc`**: the `berths` skill (the how-to Claude follows whenever it needs a device), the Fleet MCP (its tools map one to one onto the HTTP API), and `/fleet:login`, `/fleet:status`, `/fleet:sim` and `/fleet:help`.

No binary to install: the helpers are small POSIX `sh` scripts that use only `curl`, `sed` and `awk`.

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

   It shows a code like `SAIL-4821` and opens fleet.osroc.io/app/link in your browser. Check the code matches, tap **Link Claude Code**, and it prints "Signed in." The key is saved to `~/.fleet/config.json` (readable only by you); you never see or copy it. Do this once per computer.

4. **Add a Mac** at [fleet.osroc.io/app/devices/add](https://fleet.osroc.io/app/devices/add). It installs the runner; Xcode's simulators are enough to start, and a Mac with the Android SDK gets emulators too.

That's it. Ask Claude to look at your app on an iPhone, or run `/fleet:sim`. Until you log in, the commands that need Fleet say "Run /fleet:login first."

**Or by hand:** make a key at [fleet.osroc.io/app/keys](https://fleet.osroc.io/app/keys), then in Terminal run `curl -fsSL https://fleet.osroc.io/setup.sh | sh -s -- fk_your_key`. It saves the same `~/.fleet/config.json`, adds `export FLEET_KEY=…` to your shell's rc file, and checks that the fleet answers. Then the two `/plugin` lines; skip `/fleet:login`.

**Upgrading from the split plugins?** `fleet-sims` and `fleet-workflows` are gone; see [Uninstall](#uninstall) for the two lines that remove them.

## Commands

| Command | Does |
| --- | --- |
| `/fleet:sim [device] [url, bundle id, .app or .apk]` | A quick look at an app or page on an `iphone` (default), `ipad`, `appletv`, `android` or `androidtablet` berth: on screen, screenshotted, released |
| `/fleet:status` | Your Macs, their berths, current leases and what needs you |
| `/fleet:help` | A plain-words guide with examples (`/fleet:help <question>` asks about one thing) |
| `/fleet:login` | Links this computer to your Fleet |

## The skill

**`fleet:berths`** is what Claude loads when it needs to see, test, screenshot or tap an iOS, tvOS or Android app, an Expo or React Native build, or a web page. You don't run it; you ask for what you want checked. It walks Claude through the MCP: `fleet_status` (what's free), `voyage_start` (the run), `lease` (a berth: `iphone`, `iphone:pro max`, `iphone:17e`, `iphone:air`, `ipad`, `appletv`, `android`, `android:small`, `androidtablet`, with `runtime` to pick the iOS version and `sticky` for a berth the project keeps), `boot`, `install_app` (a zipped `.app`, an `.apk`, or an EAS simulator build by URL), `launch_app` (which also says whether the app crashed and which expo-updates update is running), `open_url`, `screenshot`, `describe_ui`, `tap`, `type_text`, `swipe`, `press_button`, `set_appearance`, `device_settings`, `record_start`/`record_stop`, `app_logs`, `push_notification`, `run_flow` (Maestro, with secrets by name), then `release` and `voyage_close`. Slow steps answer within 45 s and finish through `op_result`; every step carries an `op_id` so a retry never taps twice.

What it won't do: install a phone `.ipa` (berths run simulator builds; `fleet build-sim --profile preview` makes one in an Expo project), read a password into the conversation (flows name a secret; the value lives on the runner Mac, `fleet secrets set <owner/repo> <NAME>`), or reach `localhost` on your machine directly (`lease` with `metro: <port>` returns the `fleet expose` command that tunnels it).

## What's included

- **`skills/berths`**: the skill above.
- **`.mcp.json`**: the Fleet MCP at `https://fleet.osroc.io/mcp`, authenticated with your key. `scripts/fleet-headers` reads it from `FLEET_KEY` or `~/.fleet/config.json` for each connection, so the key is never written into the plugin.
- **`commands/`**: `sim`, `status`, `help`, `login`.
- **`scripts/`**: `fleet-login` (the device login), `fleet-api` (two read-only calls for `/fleet:status`: Macs and the Inbox; the key goes to `curl` on stdin and never reaches Claude), `fleet-headers`, and `lib.sh` they share.
- **`setup.sh`**: the by-hand setup.

Nothing runs on its own: the plugin has no hooks. Claude calls Fleet only inside the skill, a command, or when you ask.

## Privacy: what leaves your machine

Only what you (or Claude, on your request) send on purpose:

- **MCP calls** to fleet.osroc.io, each one visible in Claude Code as it happens: the voyage's goal and your repo's `origin` URL (credentials stripped) at `voyage_start`, then the device steps (taps, text typed with `type_text`, URLs opened, flow files) and their results. Screenshots and recordings are taken on the Mac and stored in your Fleet.
- **Uploads you make**: an app zip, an `.apk` or a flows zip, PUT to the upload URL Fleet hands out.
- **`/fleet:status`**: two authenticated GET requests (your Macs, your Inbox).
- **`/fleet:login`**: this computer's hostname, with the sign-in code.

Never sent: your prompts, Claude's replies, transcripts, file contents, or anything from sessions where you don't use Fleet. There is no session log and no hook; the plugin is silent until a Fleet tool is called. Secrets for flows are passed by name and filled in on the runner Mac.

Where things live: `~/.fleet/config.json` (your key; `/fleet:login` keeps a `login.pending` file next to it only while it waits).

## Uninstall

```
/plugin uninstall fleet@osroc
/plugin marketplace remove osroc
```

Then, in a terminal:

```sh
# If you used setup.sh: remove the "export FLEET_KEY=…  # Fleet (fleet-plugin)" line from your ~/.zshrc (or ~/.bash_profile, ~/.bashrc, ~/.profile).
# Keep ~/.fleet/config.json if you use the fleet CLI; otherwise: rm ~/.fleet/config.json
```

Revoke the key at [fleet.osroc.io/app/keys](https://fleet.osroc.io/app/keys).

**Had the split plugins?** `fleet-sims` and `fleet-workflows` are retired: their skills and commands are in `fleet` (the berths skill, `/fleet:sim`) or gone (the loop and the workflow skills). Remove them so Claude doesn't load two copies:

```
/plugin uninstall fleet-sims@osroc
/plugin uninstall fleet-workflows@osroc
```

Then `rm -rf ~/.fleet/wayfind`: the old session log's local queue, which nothing reads any more (the server answers old plugin versions that still send session events with "update the plugin").

**Had Fleet Social?** `fleet-social` is retired too: `/plugin uninstall fleet-social@osroc`, then `rm -rf ~/.fleet/social`. Its key in `~/.fleet/config.json` keeps working for `fleet`.

## Troubleshooting

- **The MCP server says 401?** The key is wrong or revoked: run `/fleet:login` again. Right after a login, the Fleet tools connect in new sessions; in an open one, run `/mcp` and reconnect fleet.
- **`/fleet-sims:sim`, `/fleet-workflows:loop` or `/fleet:find` not found?** They're gone. The quick look is `/fleet:sim`; the loop, the workflow skills and the session log were removed (Fleet is simulators now). Uninstall the old plugins as above.
- **`/fleet:login` says it isn't available yet?** Your Fleet server predates device login: use the by-hand setup above.
- **No browser on this machine (SSH)?** `/fleet:login` prints the link and code; open the link on any device where you're signed in.
- **No free berth?** `/fleet:status` shows each Mac's berths and who holds them. A lease expires 30 minutes after its last step; a Mac shown offline needs its runner started (or the Mac woken).
- **`install_app` says "This is a device build"?** Berths run simulator builds only; an `.ipa` is for phones. Use an EAS profile with `"ios": { "simulator": true }`, or `fleet build-sim --profile preview --lease <id>` in an Expo project. On Android, build an `.apk` (an `.aab` can't install).
- **`run_flow` says a secret isn't set?** On the Mac it names, run `fleet secrets set <owner/repo> <NAME>` (it asks for the value, hidden), or `fleet secrets import <owner/repo> <path to the project's env file> <NAME>...`. `fleet secrets list <owner/repo>` shows the names saved. Older runners need `fleet runner update` first.
- **A tool says the runner is out of date?** Update it from the Mac's page on the dashboard, or run `fleet runner update` on that Mac.
