---
description: Check this session is logged as a Fleet voyage (the hooks do it automatically).
allowed-tools: Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-join" *)
---

You shouldn't need this: the Fleet hooks register every session on its first hook event, including sessions that were already running when the plugin was installed. It's here as a fallback for when hooks weren't active.

This session, as Fleet sees it:

!`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-join" status "${CLAUDE_SESSION_ID}"`

- If it says `voyage: v…`, the session is already logged. Say so in one line with the voyage id and stop. Don't open a voyage.
- If it says there's no key, tell the user to run `/fleet:login` and stop.
- If it says `voyage: none`, say in one line that the hooks register this session on its next prompt (if they still don't, run `/reload-plugins`), and stop. Don't open a voyage or write log entries.
