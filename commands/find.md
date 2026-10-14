---
description: Find past Claude Code sessions in your Fleet by what was said or done in them, and print the lines to resume them.
argument-hint: "<words>"
allowed-tools: Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-api" *), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" check), Bash(grep -h *)
---

Find Fleet sessions matching: "$ARGUMENTS"

This computer's Fleet key: !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" check`

0. If the line above says `Run /fleet:login first.`, reply with exactly that and stop.
1. **Search.** With words: run `sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-api" search <the words>`. It searches every session's name, goal, prompts, log and links, and returns `results`, each with a `session` (`title`, `goal`, `repo`, `branch`, `machine`, `cwd`, `status`, `lastActivityAt`, `resumeCommand`, `voyageId`) and a `snippet` where `«…»` marks the match. With no words: run `… fleet-api sessions` for the 20 most recent.
2. **Fallback** (the search line says the server doesn't have it, or couldn't be reached): call the fleet MCP `voyage_list` with `all: true` and keep voyages whose `goal`, `summary` or ship `repo` contain every word (case-insensitive). For their session ids, `grep -h <voyage id> ~/.fleet/wayfind/sessions/*.voyages` (each file is `<session id>.voyages`, lines `<voyage id> <tab> <cwd> <tab> <opened at>`).
3. **Print** up to 10 matches, newest first, as one code block:

   ```
   cd <cwd> && claude --resume <session id>    # <title or goal> (<live|ended>, <date>) <machine>
   ```

   Use `resumeCommand` when it's there. Leave out `cd <cwd> &&` when the folder is unknown. A match without a session id (not a Claude Code session): `voyage <id>: <goal>`. Under the block, one line per match quoting its snippet only when it explains the match better than the title.
4. Nothing matched: say so in one line. Don't do anything else.
