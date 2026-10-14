---
name: ios-loop
description: Alias for /fleet:loop ios, the perpetual build loop in its iPhone mode (simulator berths, smoke tests, phone previews). Use when the user runs /fleet:ios-loop.
argument-hint: "[slots, e.g. 2] [task or issue] | resume [voyage id] | stop"
disable-model-invocation: true
---

# /fleet:ios-loop = /fleet:loop ios

Input: **$ARGUMENTS**

This is the `ios` mode of the Fleet loop. Run the Skill tool with skill `fleet:loop` and args `ios $ARGUMENTS`, and follow it. Nothing else here: the loop and its ios notes (`${CLAUDE_PLUGIN_ROOT}/skills/loop/ios.md`) hold every step.
