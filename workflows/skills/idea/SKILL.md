---
name: idea
description: Turn an idea or brain dump into researched, scoped GitHub issues, merging overlaps with existing ones. Use for /fleet-workflows:idea or "what if we…" ideas to capture. A repo's own idea skill wins.
argument-hint: "<the idea or brain dump>"
allowed-tools: Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo" *), Bash(gh issue list *), Bash(gh issue view *), Bash(gh label list *)
---

# /fleet-workflows:idea: from a brain dump to issues worth building

Idea(s): **$ARGUMENTS**

Read the shared rules once per session: `${CLAUDE_PLUGIN_ROOT}/skills/fleet-workflows/SKILL.md`.

No code and no branch here: the output is issues.

## 1. Split, then know what exists

- Split a brain dump into separate ideas. Keep the user's words for each.
- `sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"` (is `gh` installed, which repo).
- Read the existing issues, open and closed, before writing anything: `gh issue list --state all --limit 300 --json number,title,labels,state`, then `gh issue list --state all --search "<keywords>"` per idea and `gh issue view <n>` for close matches. A roadmap or epic issue, if the repo has one, is where new ideas hang.

## 2. Combine instead of duplicating

- **Already an issue:** add to it (a "More from <user>, <date>" section with the new angle). Don't open another.
- **Two or more existing issues overlap:** merge into the most complete one, move the other's content across, and close it with "Merged into #N", keeping its open questions.
- **Closed or shipped:** say so. If the idea extends it, open a follow-up that links the original.

## 3. Research each new idea

Short and concrete:

- **Context:** what the user asked, in their words.
- **Findings:** how it works today (`file:line`), the data that exists or is missing, the cost of the obvious approach, and what similar products do (with links when you looked them up).
- **Options:** two or three ways to do it, with effort and risk.
- **Recommendation:** one, and why.
- **Open questions** for the user, as checkboxes, so nothing is forgotten.
- **Proposed tasks:** a checklist of PR-sized steps.
- **Is it open-ended?** Say whether the look or feel is still undecided (a prototype first) or it's clear enough to build.

## 4. File it

With `gh` and a GitHub remote:

```sh
gh issue create --title "<idea, in plain words>" --body-file <scratch>/<idea>.md [--label <existing label>]
```

Use labels the repo already has (`gh label list`); the settings' `issues.labels` if set. Attach it under the roadmap or epic issue if there is one (`--parent <n>` where supported, else a link in the body). No credentials, no private data in issues.

Without `gh` or a GitHub remote: give the issues as Markdown in the chat, ready to paste, and say where they'd go.


## Report

Opening lines: new issues (links), issues updated or merged (links, what changed), and the one or two questions that most need the user. Then the closing sections (shared rules § Reporting).

**Next:** for an idea whose look or feel is open → `fleet-workflows:prototype <issue>`; for one that's clear → `fleet-workflows:build <issue>`. Offer the one that fits; start it only if the user said to keep going.
