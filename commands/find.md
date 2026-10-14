---
description: Find past voyages (Claude Code sessions) and print the lines to resume them.
argument-hint: "<words>"
allowed-tools: Bash(grep -h *), Bash(cat *), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" *)
---

Find Fleet voyages matching: "$ARGUMENTS"

This computer's Fleet key: !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" check`

0. If the line above says `Run /fleet:login first.`, reply with exactly that and stop.

1. Call the fleet MCP `voyage_list` with `all: true`. Keep the voyages whose `goal`, `summary` or ship `repo` contain every word of the query (case-insensitive). With no query, keep the 10 most recent.
2. For each match, find its Claude Code session id:
   - Local sessions on this machine: `grep -h <voyage id> ~/.fleet/wayfind/sessions/*.voyages`. Each line is `<voyage id> <tab> <cwd> <tab> <opened at>`, and the file's name is `<session id>.voyages`.
   - Otherwise a closed voyage's `summary` ends with `Resume: claude --resume <session id>`, and the voyage's first note (from `voyage_resume`) says `Session <id> on <machine>. Resume: cd <dir> && claude --resume <id>`. Only call `voyage_resume` for matches you still can't place, and at most 5.
3. Print one line per match, newest first, as a code block:

   ```
   cd <dir> && claude --resume <session id>    # <goal> (<open|closed>, <date>)
   ```

   Leave out `cd <dir> &&` when you don't know the folder. If a voyage has no session id (it wasn't a Claude Code session), print `voyage <id>: <goal>` instead.
4. Nothing matched: say so in one line. Don't do anything else.
