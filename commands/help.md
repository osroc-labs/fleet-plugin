---
description: How to use Fleet, in plain words, with examples of the everyday workflows. Start here.
disable-model-invocation: true
allowed-tools: Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" check)
---

This computer's Fleet key: !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" check`

Show the guide below to the person, as written (Markdown). Plain words only; don't call any tools.

- If the key line above says `Run /fleet:login first.`, put this one line at the very top: **You're not signed in yet. Run `/fleet:login` first (it opens a link to approve; no key to copy).**
- If `$ARGUMENTS` is not empty, they asked about something specific: answer that first in a few lines (using the guide below), then show only the guide's most relevant section, not the whole thing.

---

# Fleet: how it works

Fleet is a dashboard and a set of commands for building with Claude Code. You talk to Claude like normal; Fleet keeps track of everything in one place at **https://fleet.osroc.io/app**:

- **Sessions:** every Claude Code session, named like it is in Claude, with the conversation and what it shipped. Pick any of them back up later.
- **Inbox:** what's waiting on you: questions, permission prompts, options to pick, work to review.
- **Prototypes:** side-by-side options to choose from before anything gets built.
- **Projects:** your repos. A repo shows up on its own the first time you run Claude in it.
- **Devices:** iPhone, iPad and Apple TV simulators on your Macs that Claude can use to look at and test your app.

You never have to open the dashboard to use it, but it's where you pick, review and catch up.

## First time (2 minutes)

1. Sign in at https://fleet.osroc.io/app (or open the invite link a friend sent).
2. In Claude Code: `/fleet:login`, then approve the link it opens.
3. Start working in any repo. That's it: the session shows up in Sessions.

Optional: to let Claude use simulators on a Mac, add it at https://fleet.osroc.io/app/add.

## Everyday workflows (examples)

**"I just want to build something."**
```
/fleet:build add a dark mode toggle to settings
```
Claude makes a branch, builds it, tests it and opens a pull request. You review and say ship.

**"I'm not sure what it should look like."**
```
/fleet:prototype three ideas for the onboarding screen
```
You get 2 to 4 options in Prototypes. Tap the one you like (or ask for another round); Claude builds your pick.

**"Something is broken."**
```
/fleet:triage the login button does nothing on iPhone
```
Claude reads the errors first, finds the cause, fixes it on a branch and checks the fix.

**"I have a bunch of ideas."**
```
/fleet:idea a weekly recap email, shared lists, and a better search
```
Claude turns them into clear, researched GitHub issues ready to build.

**"Keep building while I'm away."**
```
/fleet:loop
```
Claude works through your backlog one task at a time: builds, checks, puts each one in your Inbox for review, and ships it when you say so. `/fleet:loop 2` runs two at once. Type **stop** to end it.

**"Ship it."**
```
/fleet:ship
```
Merges and deploys, only after your yes, then checks production.

## Handy commands

| Command | What it does |
| --- | --- |
| `/fleet` | The front door: what's waiting on you and which workflow fits what you describe |
| `/fleet:help` | This guide (`/fleet:help <question>` to ask about one thing) |
| `/fleet:status` | Your Macs, what's waiting on you, live sessions |
| `/fleet:find <words>` | Find a past session by what was said in it, and how to resume it |
| `/fleet:verify` | Check that something actually works |
| `/fleet:review` | A fresh-eyes review of a branch or pull request, with fixes |
| `/fleet:login` | Sign this computer in |

## Good to know

- **Name your sessions** with `/rename <name>` in Claude; Fleet uses the same name. When the topic changes, Claude suggests a new name.
- **Every report ends the same way:** Callouts, Waiting on you, PR links and Options waiting on you, with a link on everything you need to do. "Live" means you can open it, not just merged.
- **Agents pick the right model for the job** (the strongest for anything you'll see, a lighter one for small fixes, checked by the strongest) and work in their own git worktrees, never your checkout.
- **Say "always" or "never" and it sticks:** Claude writes the rule into your repo with the date and your words, not just its memory.
- **Nothing ships without your yes.** Claude asks in your Inbox or in chat before anything goes to production.
- **On your phone?** The dashboard works there too: answer questions and pick options from anywhere.
- **Updating Fleet:** in a terminal, run `claude plugin marketplace update osroc` and then `claude plugin update fleet@osroc`, then start a new session.
- **Something looks off?** `/fleet:status` shows whether you're signed in and your Macs are online.
