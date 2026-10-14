---
description: Commission this repo as a ship in your Fleet, with the vessel of your choice.
argument-hint: "[vessel]"
allowed-tools: Bash(git remote get-url origin), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" *)
---

Commission the current repo as a ship in the user's Fleet.

This computer's Fleet key: !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" check`

The repo: !`git remote get-url origin 2>/dev/null || echo "(no origin remote)"`

The vessels: carrier, battleship, destroyer, submarine, frigate, galleon, longship, junk, tugboat, hydrofoil, catamaran, speedboat, jet ski, canoe, raft, rubber duck.

The vessel asked for: "$ARGUMENTS"

0. If the Fleet key line above says `Run /fleet:login first.`, reply with exactly that and stop.
1. If there's no origin remote, say that a ship is a git repo with a remote, and stop.
2. If no vessel was given, list the sixteen vessels on one line and ask which one. Stop there; when the user answers, carry on with step 3.
3. If the vessel isn't one of the sixteen, say so, list them, and ask again. Pass `jet ski` as `jet_ski` and `rubber duck` as `rubber_duck`.
4. Call the fleet MCP tool `ship_commission` with `repo` (the remote above) and `vessel`. Reply with one line: the ship and its vessel.
5. If the fleet MCP has no `ship_commission` tool yet, fall back: a voyage sights the ship as a raft. Call `voyage_start` with `repo` and goal `Commission <repo name>`, then `voyage_close` it with summary `Ship sighted`. Then tell the user, in one line, to pick the vessel on the ship at https://fleet.osroc.io/app.
