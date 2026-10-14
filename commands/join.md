---
description: Board this session onto a Fleet voyage by hand. You shouldn't need it; the hooks register every session automatically.
allowed-tools: Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-join" *)
---

You shouldn't need this: the Fleet hooks register every session on its first hook event, including sessions that were already running when the plugin was installed. It's here as a fallback for when hooks weren't active.

This session, as Fleet sees it:

!`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-join" status "${CLAUDE_SESSION_ID}"`

- If it says `voyage: v_…`, the session is already logged. Say so in one line with the voyage id and stop. Don't open another voyage.
- If it says there's no key, tell the user to run the setup line from the fleet-plugin README and stop.
- If it says `voyage: none`, board it:
  1. Call the fleet MCP `voyage_start` with `goal` (one sentence: what this session is for, from the conversation so far), `repo` (the `repo` line, if any) and `git` (`branch`, `sha`, `pushed`, `host` from the lines above).
  2. Link it, so the hooks keep appending to this voyage: `sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-join" link "${CLAUDE_SESSION_ID}" <voyage id>`.
  3. Post 2 to 5 `voyage_log` entries with kind `note`, one per key decision made so far (a sentence each, under 1000 characters).
  4. Post one `voyage_log` entry with kind `state`: where things stand now, 280 characters or fewer.
  5. Reply with one line: the voyage id and what you logged.
