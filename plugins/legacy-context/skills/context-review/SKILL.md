---
name: context-review
description: Audits the context architecture of a repository - checks whether the root AGENTS.md/CLAUDE.md has ballooned, cuts redundant and stale rules, judges from signals whether it is time for a per-module AGENTS.md or a separate context/ inside a module (the maturity ladder), and verifies that context/ has not rotted. Use this whenever the user says "review my AGENTS.md", "CLAUDE.md is too long", "the agent ignores my rules", "context audit", "should I split AGENTS.md per module", "rule review", "clean up context/", or whenever you notice an instruction file past roughly 300 lines.
---

# Context review - auditing the context architecture

The context window is a finite attention budget, not an unlimited warehouse. The more you keep loaded permanently, the less attention remains for the task at hand.

Four failure modes of a monolithic instruction file - look for each specifically:

1. **It crowds out the task** - more standing instructions, less room for what you are doing now.
2. **It dilutes guidance** - when everything is important, nothing is.
3. **It rots** - rules go stale faster than anyone reviews them.
4. **It resists verification** - the longer the file, the harder it is to check whether the agent follows it.

The key finding from research on this: the culprit is **redundancy and unnecessary requirements**, not raw length. Excess context can simultaneously raise cost and degrade the result. So cut for redundancy, not for the line counter.

## Step 1: inventory

```bash
# Every instruction file with its line count AND its own last real change date.
find . -maxdepth 4 \( -name 'AGENTS.md' -o -name 'CLAUDE.md' -o -name '*.mdc' \) \
  -not -path '*/node_modules/*' \
| while IFS= read -r f; do
    printf '%s\t%s\t%s\n' \
      "$(wc -l < "$f")" \
      "$(git log -1 --date=short --pretty=%ad -- "$f" 2>/dev/null || echo untracked)" \
      "$f"
  done | sort -rn
```

Two traps this avoids. `git log -1 -- AGENTS.md CLAUDE.md` returns a single newest commit across **both** files, so a root untouched for a year looks fresh because its sibling was edited yesterday - query each file separately. And filesystem mtime (`find -mtime`) is not "last real change": a fresh `git clone` stamps every file with today's date, so in the exact scenario this skill exists for - entering someone else's repo - an mtime check returns nothing at all. Ask git, never the filesystem.

Same command shape for `context/`, to find what has gone stale:

```bash
find context -name '*.md' 2>/dev/null | while IFS= read -r f; do
  printf '%s\t%s\n' "$(git log -1 --date=short --pretty=%ad -- "$f" 2>/dev/null)" "$f"
done | sort
```

An instruction file untouched for a year in an actively developed repo is suspect regardless of its length.

## Step 2: rule-by-rule review

Read the root and, for **each** rule, answer:

| Question | Verdict on "no" |
|---|---|
| Can it be inferred from the code / config / linter? | **remove** - the linter enforces it more cheaply |
| Does it prevent a mistake that actually occurred? | **removal candidate** |
| Is it needed **constantly and globally**? | **move to `context/`** and leave a reference |
| Is it still true? | **remove or fix** |
| Does it duplicate another rule? | **merge** |
| Does it concern fast-changing facts? | **move** - a slow-changing file should not hold fast-changing facts |

Typical cut candidates: descriptions of every folder, project history, changelogs, generic programming advice ("write readable code"), README duplicates, dependency lists, anything already enforced by ESLint/ruff/CI.

Present the user with a **proposal** - what to cut, move and keep - with a one-sentence rationale each. Do not delete anything without approval; these are their rules, and some guard against failures you cannot see from history.

## Step 3: the maturity ladder - should structure be added

The rungs:

1. **root AGENTS.md + a `context/` folder** - the starting point for every project,
2. **per-module AGENTS.md + an index in the root** - when a module has its own specific patterns or its own team,
3. **its own `context/` inside a module** - when the module needs a dedicated PRD/roadmap.

**The decision rule is not "my project is big".** You climb **in response to a signal**:

- the root has ballooned and become unreadable (guideline: aim under ~200 lines, consider splitting past ~300),
- the agent **repeatedly** loses context for one specific module and repeats the same mistakes despite fixes in the root,
- every time you work in that module you hand over more and more references to its documentation,
- the module gained its own deploy or owner - a real boundary of responsibility.

No signal → **stay on the first rung**. Building per-folder files preemptively is paying for structure that yields nothing. Say this plainly to the user, even when they expect a "split it up" recommendation.

## Step 4: how to extract a module (when the signal is real)

Do **one module at a time**. The child file opens with an inheritance line and adds **only** what cannot be inferred from the root:

```markdown
# packages/wrangler/AGENTS.md
Wrangler-specific context only. See root AGENTS.md for monorepo conventions.

## Gotchas
- Entry point is `src/cli.ts`, NOT `src/index.ts`
- No `console.*` - use the `logger`

## Anti-Patterns
- ...
```

And the root gains an explicit index:

```markdown
## Packages with their own AGENTS.md
- packages/wrangler/AGENTS.md - CLI architecture, command structure, test patterns
- packages/miniflare/AGENTS.md - Worker simulation
```

The child file **copies nothing from the root**. If it repeats monorepo conventions, you have duplicated the problem instead of solving it.

## Step 5: loading mechanics - without this, extraction does not work

Tools load instruction files by **extension, not replacement**. A file closer to the task adds to the root; it does not erase it. The assumption "the nearest file wins and replaces the rest" is wrong.

- **Claude Code** walks from the filesystem root downward and concatenates the files it finds (the nearest is read last, so it appends rather than overrides). Files in subdirectories load **lazily** - only when the agent reaches into that part of the tree - and they do so with **varying reliability**. `@path` imports expand at session start and **do not save tokens**; they paste the content in. Claude Code is the one popular tool that does not read `AGENTS.md` (it uses `CLAUDE.md`).
- **Codex** detects the repo root, assembles files downward **once at startup**, with no lazy loading. It has a **shared size limit** across all concatenated files (`project_doc_max_bytes`, on the order of tens of KiB, varying between versions) - past which content is **silently truncated**.
- **Cursor** offers four rule types: always on, selected by task description, attached via globs, invoked manually.
- **Copilot** merges a rule matched by `applyTo` with the general repo rule.

The practical takeaway for the user: **if a module's rules are critical, start the agent from inside the module or hand it an explicit reference to the file.** Relying on lazy loading when starting from the root is a bet, not a guarantee.

## Step 6: `context/` hygiene

- files in `map/` whose last git commit is older than ~6 months - flag them as needing a rescan (a map without a scan date is worse than no map),
- finished changes move from `changes/` to `archive/` so they stop cluttering current work,
- does `context/README.md` still describe the real structure?
- does anything in `context/` duplicate the root? Keep one source.

## Report

Summarize: before/after (root line count), the list of cut rules with rationale, the list of moved rules with their new path, the ladder verdict (**we stay / we extract module X, because of signal Y**), and a review cadence (quarterly).

Propose a concrete date for the next review. Rules rot silently; the only things that meaningfully slow the decay are a periodic review and not putting fast-changing facts into slow-changing files.
