---
description: How to use Fleet, with examples.
allowed-tools: Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" check)
---

This computer's Fleet key: !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" check`

Show the guide below to the person, as written (Markdown). Plain words only; don't call any tools.

- If the key line above says `Run /fleet:login first.`, put this one line at the very top: **You're not signed in yet. Run `/fleet:login` first (it opens a link to approve; no key to copy).**
- If `$ARGUMENTS` is not empty, they asked about something specific: answer that first in a few lines (using the guide below), then show only the guide's most relevant section, not the whole thing.

---

# Fleet: how it works

Fleet turns the Macs you already own into simulators and emulators that Claude can use. Instead of guessing what your app looks like, Claude leases an iPhone, iPad, Apple TV or Android berth on one of your Macs, puts your app on it, looks at it, taps through it, and hands it back. The dashboard at **https://fleet.osroc.io/app** shows your Macs, their berths, what's running now and what needs you.

- **Macs:** each Mac you add runs simulators (and Android emulators, when it has the SDK). Pause one, update its runner, or remove it from its page.
- **Berths:** a simulator or emulator slot on a Mac. Claude leases one for a job, every step runs on the Mac, and the berth is erased when it's released, unless it's a project's sticky berth (kept with its apps and sign-ins).
- **Runs:** each lease and what happened on it: steps, screenshots, flows, the outcome, with the device drawn live while it runs.
- **Projects:** your repos, with their sticky berths and the names (never the values) of the test accounts their flows use.

You never have to open the dashboard to use Fleet, but it's where you watch a run and catch up.

## First time (2 minutes)

1. Sign in at https://fleet.osroc.io/app (or open the invite link a friend sent).
2. In Claude Code: `/fleet:login`, then approve the link it opens.
3. Add a Mac at https://fleet.osroc.io/app/add (it installs the runner; Xcode's simulators are enough to start).

Then ask Claude to look at your app, or run `/fleet:sim`.

## Everyday examples

**"Show me the app on an iPhone."**
```
/fleet:sim iphone com.example.app
/fleet:sim ipad https://example.com
/fleet:sim android app/build/outputs/apk/debug/app-debug.apk
```
A quick look: one berth, the app or page on it, a screenshot, released. Give it a URL, an installed bundle id (package name on Android), a path to a simulator `.app`, or an `.apk`.

**"Test the login flow on a real simulator."**
Just ask. Claude loads the `berths` skill, opens a voyage, leases a berth, installs or opens your app, taps through with `describe_ui` and `tap`, screenshots each step, and releases the berth at the end. It picks the iOS your users run when you say so (`runtime: newest`, `previous`, `beta` or a version).

**"Run our Maestro flows."**
Claude runs them on the berth with `run_flow`. Test-account credentials go by **name** only: save them once on each Mac with `fleet secrets set <owner/repo> <NAME>`, and the values never pass through Claude.

**"Does the Expo update reach the installed build?"**
`launch_app` says which over-the-air update is running and whether the app crashed, with the crash report. No simulator build yet? `fleet build-sim --profile preview` makes one on your Mac (a phone `.ipa` won't run on a simulator).

**"Load my dev server on the device."**
A berth can't reach `localhost` on your machine. `lease` with a Metro port returns the `fleet expose` command that tunnels it; the dev client on the berth loads the bundle from your machine.

## Commands

| Command | What it does |
| --- | --- |
| `/fleet:sim [device] [url, bundle id, .app or .apk]` | A quick look on an iPhone, iPad, Apple TV or Android berth, screenshotted and released |
| `/fleet:status` | Your Macs, berths, leases and what needs you |
| `/fleet:help` | This guide (`/fleet:help <question>` to ask about one thing) |
| `/fleet:login` | Sign this computer in |

The `berths` skill (`fleet:berths`) is the how-to Claude follows whenever it needs a device; you don't run it, you just ask for what you want to see or test.

## Good to know

- **Every lease is released.** A held berth blocks everyone else, so Claude releases it even after a failure, and a lease expires on its own after 30 minutes without activity.
- **Sticky berths** keep a project's apps and sign-ins between leases (`sticky: true`); erase one with `reset_berth`, or unpin it to give it back.
- **Simulator builds only.** A store or ad hoc `.ipa` is for phones; use an EAS profile with `"ios": { "simulator": true }`, or `fleet build-sim`. On Android, an `.apk` (an `.aab` can't install).
- **On your phone?** The dashboard works there too: watch a run and see what needs you from anywhere.
- **Updating Fleet:** in a terminal, run `claude plugin marketplace update osroc` and then `claude plugin update fleet@osroc`, then start a new session. Runners update from the Mac's page, or with `fleet runner update` on the Mac. What changed in each version: `CHANGELOG.md` in the plugin.
- **Something looks off?** `/fleet:status` shows whether you're signed in and your Macs are online.
