---
description: Sign this computer in to Fleet Social. Opens a link to approve; no key to copy, no terminal.
allowed-tools: Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/social-login" *)
disable-model-invocation: true
---

Sign this computer in to Fleet Social. The plugin's `social-login` script asked Fleet for a sign-in code:

!`sh "${CLAUDE_PLUGIN_ROOT}/scripts/social-login" start`

1. If the output above has no `Your Fleet code:` line, reply with its first line exactly and stop.
2. Otherwise reply with the code and the link from it, in two short lines, and say the page is opening in their browser. Nothing else.
3. Then run the `wait` command it printed (the same `social-login` script with `wait`), with the Bash tool's timeout set to 600000. It returns once the code is approved, cancelled or expired, up to 10 minutes.
4. Reply with its output exactly. Don't run anything else.
