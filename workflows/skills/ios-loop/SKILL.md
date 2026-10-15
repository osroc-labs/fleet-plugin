---
name: ios-loop
description: Alias for /fleet-workflows:loop ios (the iPhone build loop). Use for /fleet-workflows:ios-loop.
argument-hint: "[lanes, e.g. 2] [task or issue] | resume [voyage id] | stop"
disable-model-invocation: true
---

# /fleet-workflows:ios-loop = /fleet-workflows:loop ios

Input: **$ARGUMENTS**

This is the `ios` mode of the Fleet loop. Run the Skill tool with skill `fleet-workflows:loop` and args `ios $ARGUMENTS`, and follow it. Nothing else here: the loop and its ios notes (`${CLAUDE_PLUGIN_ROOT}/skills/loop/ios.md`) hold every step.
