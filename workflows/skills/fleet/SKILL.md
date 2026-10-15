---
name: fleet
description: Fleet's front door, listing the workflows (loop, idea, prototype, build, verify, review, ship, triage), what's waiting on you, and which fits. Use for /fleet or "what can Fleet do".
argument-hint: "[what you want to do]"
allowed-tools: Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-api" *), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo" *), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" check)
---

# /fleet

What the user wants: "$ARGUMENTS"

This computer's Fleet key: !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" check`

Waiting on the user in Fleet (raw; the Inbox): !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-api" inbox`

This repo: !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo" --short`

## The loop

**`/fleet-workflows:loop`** keeps building on this project until you say stop: it picks the next task (your Fleet Inbox, then GitHub issues, then the roadmap), shows options first when it's open-ended, builds, checks and reviews it, puts it up for your review in Fleet, and ships it on your green (production still needs your yes unless you've turned on `greenShips`). Then the next one.

- Modes: `ios` (simulators), `web` (preview URL or dev server), `api`, `cli`, `prototype-only` (options, no building); picked from the repo when you don't say.
- `/fleet-workflows:loop 2` runs two tasks at once, each on its own simulator. `/fleet-workflows:ios-loop` is `/fleet-workflows:loop ios`.

## The single steps

The loop runs these for you; each also works on its own.

| Command | For |
| --- | --- |
| `/fleet-workflows:idea` | Turn a brain dump into researched, scoped GitHub issues |
| `/fleet-workflows:prototype` | 2–4 different options side by side in Fleet; you pick, then it gets built |
| `/fleet-workflows:build` | Build a feature on a branch, tested, with a PR |
| `/fleet-workflows:verify` | Check a change really works (tests plus a real look) and report pass or fail |
| `/fleet-workflows:review` | An independent review of a branch or PR, with fixes |
| `/fleet-workflows:ship` | Merge and deploy, only with your yes |
| `/fleet-workflows:triage` | "It's broken": logs first, find the cause, fix, verify |
| `/fleet-sims:sim` | Quick look at an app or page on an iPhone, iPad or Apple TV simulator |
| `/fleet:status` | Your Macs, simulators and what's waiting on you |
| `/fleet:find` | Find a past session and the line to resume it |

## What to reply

Keep it short and plain. No naval words here.

1. **If the key line says `Run /fleet:login first.`:** one line saying Fleet isn't linked on this computer (`/fleet:login` takes a minute). The workflows still run without it; prototypes and reviews then stay in chat instead of Fleet.
2. **Waiting on you:** from the Inbox JSON above, list up to 5 items, one line each: what it is (a pick, a review, a question, a session waiting on permission, an offline Mac), its goal or line, and its link (`https://fleet.osroc.io` + its `href`). Skip storms and moods. If it's empty, say "Nothing's waiting on you." If it couldn't be read, say so in one line and move on.
3. **If the user described what they want** (the quoted text above isn't empty): name the one workflow that fits and why, in one sentence, then start it with the Skill tool when they clearly asked for it to happen ("prototype the onboarding", "ship #12"); otherwise ask "Want me to start it?". How to choose:
   - "keep building", "work through the backlog", "next task", a sprint on this project → `fleet-workflows:loop` (with the mode if they named one: "the iPhone app" → `ios`)
   - a loose idea, a wish list, "what if we…" → `fleet-workflows:idea`
   - "show me options", a redesign, a look or feel that's open → `fleet-workflows:prototype`
   - a clear feature or change → `fleet-workflows:build` (it hands iOS/Expo/React Native work to `fleet-workflows:loop ios`)
   - "does it work?", "check it" → `fleet-workflows:verify`
   - "review this PR/branch" → `fleet-workflows:review`
   - "ship it", "deploy", "merge it" → `fleet-workflows:ship`
   - "it's broken", an error, a crash → `fleet-workflows:triage`
   - "show me it on an iPhone" → `fleet-sims:sim`
4. **Otherwise:** lead with the loop in one line (`/fleet-workflows:loop` keeps building on this project, task after task, in the mode it detects), then the single steps as a short list, then one line: "Tell me what you're working on and I'll pick the workflow."

If the repo has its own skill for a step (`skills` in its settings, or a same-named skill on the repo line), say that one runs instead of Fleet's for that step; the loop itself stays in Fleet.
