---
name: context-scaffold
description: Sets up a context/ directory (foundation, map, changes, archive) plus a lean root AGENTS.md/CLAUDE.md that works as a table of contents rather than an encyclopedia. Use this whenever the user says "set up context", "initialize context/", "prepare this repo for an agent", "onboard an agent to this project", "write an AGENTS.md for a large project", or whenever they start analyzing a legacy codebase (repo map, feature analysis, refactor plan) in a repo that has no context/ directory yet - in that case offer this as the first step.
---

# Context scaffold

Goal: set up a memory layer the agent reaches into just-in-time, instead of keeping all project knowledge in one instruction file.

The split you are implementing:
- **conventions** (how we work in this project) → root `AGENTS.md` / `CLAUDE.md`,
- **references** (PRD, maps, research, plans, decisions) → `context/`,
- **procedures** (repeatable steps) → skills and commands.

The root is a table of contents. It holds what applies to the whole project and is needed **constantly**. Anything the agent needs only sometimes lives in `context/` and is pointed at by reference.

## Step 1: look before you create anything

Never overwrite someone else's work. Check first:

```bash
ls -a                                  # AGENTS.md, CLAUDE.md, .cursor/, .github/
wc -l AGENTS.md CLAUDE.md 2>/dev/null  # has the root already ballooned
ls context 2>/dev/null                 # does the structure exist already
git rev-parse --is-inside-work-tree    # is this even a git repo
```

What follows from each finding:
- `AGENTS.md`/`CLAUDE.md` already exists → **do not generate a new one**. Add a `Reference` section pointing at `context/`, and if it runs past ~300 lines, offer a review (the `context-review` skill).
- `context/` already exists → add only the missing subdirectories, leave the contents alone.
- No git repo → say so plainly; the `repo-territory` and `repo-contributors` skills need history to work at all.

## Step 2: directory structure

```
context/
├── README.md          # index for agent and human: what lives where
├── foundation/        # durable ground truth: prd.md, tech-stack.md, roadmap.md, test-plan.md
├── map/               # repository map (working artifacts + repo-map.md)
├── changes/           # individual changes: <id>/research.md, plan.md
└── archive/           # finished changes, so they stop cluttering current work
```

Create the directories and a `.gitkeep` in empty ones. In `foundation/`, **do not generate filled-in documents out of thin air** - your knowledge of this project is currently zero, and an invented PRD is worse than no PRD. Leave short stubs with a heading and a "to be filled in" line, or skip them and tell the user they will emerge from real work.

## Step 3: `context/README.md`

This file is cheap and gets read by both the agent and any new human. Keep it under 40 lines:

```markdown
# Context

System of record for this repository. The agent reaches in just-in-time - usually
because it was handed an explicit reference to a specific file.

| Path | What lives here | When to read it |
|---|---|---|
| `foundation/` | PRD, tech stack, roadmap, test plan | working on product scope |
| `map/repo-map.md` | repo map: risk zones, entry points | entering an unfamiliar area |
| `changes/<id>/` | research and plan for one change | working on that change |
| `archive/` | closed changes | only when digging for past decisions |

Rule: files in `map/` are **dated and evidence-based**. If the evidence comes from
a 12-month window, the map says nothing about the state before that window.
```

## Step 4: root AGENTS.md (only if none exists)

Target: 50-120 lines. Every line has to earn its place in the context window.

Before writing, gather **facts, not guesses**: read `package.json` / `pyproject.toml` / `go.mod` / `Makefile`, the CI config, linter and test configuration. Commands in AGENTS.md must be copied from a real script, not invented.

Template:

```markdown
# <project name>

## Project
Two or three sentences: what this is, who it serves, what the main flow is.

## Commands
Only the ones the agent uses daily: install, dev, test, lint, build, typecheck.
Copied from package.json / Makefile, not made up.

## Architecture
Layers and boundaries in 5-10 bullets. Where the entry point is, where domain logic
lives, where the contracts between layers sit. Not a description of every folder.

## Conventions
Rules that cannot be inferred from the code itself: naming, error handling, forbidden
patterns, how tests are written. Each rule should be one you have actually seen broken,
or one that prevents a recurring mistake.

## Reference
- `context/map/repo-map.md` - repository map and risk zones
- `context/foundation/` - PRD, tech stack, test plan
- `context/changes/<id>/` - research and plans for individual changes
```

What does **not** belong in the root: the PRD, project history, a description of every module, changelogs, anything that changes weekly. A slow-changing file should not hold fast-changing facts - otherwise it rots before anyone reviews it.

If the user's tool is Claude Code, the file is named `CLAUDE.md` (Claude Code is the one popular tool that does not read `AGENTS.md`). When unsure, offer `AGENTS.md` plus a one-line `CLAUDE.md` containing `See @AGENTS.md`.

## Step 5: what to say at the end

Summarize briefly: what was created, what you deliberately left empty, and what comes next. If the user arrived here in a legacy context, the natural follow-up is building the repository map (`repo-territory` → `repo-structure` → `repo-contributors` → `repo-map`).

Do not immediately propose per-module `AGENTS.md` files or separate `context/` directories inside modules. Those are higher rungs on the maturity ladder; you climb them in response to a signal (the root balloons, the agent repeats mistakes in a specific module, the module has its own team or deploy), not preemptively. Assessing that signal is the `context-review` skill's job.
