---
description: Your Fleet at a glance, with Macs, simulators, live sessions and what's waiting on you.
disable-model-invocation: true
allowed-tools: Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-api" *), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" check)
---

This computer's Fleet key: !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" check`

Macs and simulators (raw): !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-api" macs`

Waiting on you (raw): !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-api" inbox`

Live sessions (raw): !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-api" sessions live`

0. If the key line says `Run /fleet:login first.`, reply with exactly that and stop.
1. Reply in plain words, three short sections, no naval words and no JSON:
   - **Macs:** one line per Mac (`harbors`): name, online or offline, and its simulators as counts (free, in use, offline), e.g. `macbookpro · online · 3 iPhones free, 1 in use`. A berth is free when its `state` is `ashore`, in use when `at_sea`. None: "No Macs yet. Add one at https://fleet.osroc.io/app/add".
   - **Waiting on you:** one line per Inbox item (skip `storm`): what it is, its goal or line, and its link (`https://fleet.osroc.io` + `href`). None: "Nothing."
   - **Live now:** one line per live session: its title or goal, repo, machine. None: "No live sessions."
2. If a section couldn't be read, say so in its one line. Don't call any tools.
