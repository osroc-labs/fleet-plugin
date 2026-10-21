---
description: Your Fleet at a glance, with Macs, berths, leases and what needs you.
disable-model-invocation: true
allowed-tools: Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-api" *), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" check)
---

This computer's Fleet key: !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" check`

Macs and berths (raw): !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-api" macs`

Needs you (raw): !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-api" inbox`

0. If the key line says `Run /fleet:login first.`, reply with exactly that and stop.
1. Reply in plain words, four short sections, no naval words and no JSON:
   - **Macs:** one line per Mac (`harbors`): its `label`, its `status` (online, paused or offline; offline comes with `offline.note`), and an `update` note when it has one. A Mac with `lentBy` is someone else's, lent to you: say whose. None: "No Macs yet. Add one at https://fleet.osroc.io/app/add".
   - **Berths:** one line per Mac counting its `berths` by `kind` and `state`: `ashore` is free, `at_sea` is in use, `adrift` means the Mac is offline, e.g. `3 iPhones free, 1 in use, 1 iPad free, 2 Android free`. A berth with `reservedFor` is a project's sticky berth: name the project (`reservedFor.repo`).
   - **Leases:** one line per berth that has a `lease`: the device (`device`, `runtime`), the Mac, the voyage (`lease.voyageId`, or "lent to <name>" when `lentTo`), and when it expires (`lease.expiresAt`, as "in N minutes"). None: "Nothing leased."
   - **Needs you:** one line per item in the Inbox (skip `storm`): what it is, its line, and its link (`https://fleet.osroc.io` + `href`). Offline Macs and runners with an `update` note count here too, once each. None: "Nothing."
2. If a section couldn't be read, say so in its one line. Don't call any tools.
