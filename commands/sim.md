---
description: Quick look at an app or page on a Fleet iPhone, iPad, Apple TV or Android berth, screenshot it, then release it.
argument-hint: "[iphone|ipad|appletv|android|androidtablet] [url | bundle id | path/to/App.app | app.apk]"
disable-model-invocation: true
allowed-tools: Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" check), Bash(git remote get-url origin), Bash(ditto *), Bash(curl -sS -T *)
---

A quick look on a simulator: "$ARGUMENTS"

This computer's Fleet key: !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" check`

0. If the key line says `Run /fleet:login first.`, reply with exactly that and stop.
1. **What to show:** the device is the first word if it's `iphone`, `ipad`, `appletv`, `android` or `androidtablet` (default `iphone`; an `.apk` path means `android`). The rest is a URL (`https://…` or a deep link), an installed bundle id (package name on Android), a path to a `.app` built for the simulator, or an `.apk`. Nothing given: ask what to show, in one line, and stop.
2. **A voyage and a simulator:** `voyage_start` with goal `Look at <what> on <device>`, `repo` from `git remote get-url origin` (leave it out outside a repo) and an `op_id`. `lease` with the device as `target` and `wait_seconds: 45` (the most one call waits), then `boot`. No free simulator: say so with what `fleet_status` shows, close the voyage, stop.
3. **Show it:**
   - a URL: `open_url`;
   - a `.app` path: zip it (`ditto -c -k --sequesterRsrc --keepParent <App.app> <scratch>/app.zip`), `upload_url` with `ext: "zip"`, `curl -sS -T <scratch>/app.zip '<uploadUrl>'`, `install_app` with the `blob_key`, then `launch_app` with the returned bundle id;
   - an `.apk` path: `upload_url` with `ext: "apk"`, `curl -sS -T <app.apk> '<uploadUrl>'`, `install_app` with the `blob_key`, then `launch_app` with the returned package;
   - a bundle id: `launch_app`.
4. `screenshot`, look at it, and show the user in two lines: what's on screen and the screenshot link. If the user asked to tap through something, do it with `describe_ui`, `tap`, `type_text` and `swipe`, screenshotting each step.
5. **Always** `release` the lease and `voyage_close` the voyage (summary: one line), even after a failure. Say it's released.
