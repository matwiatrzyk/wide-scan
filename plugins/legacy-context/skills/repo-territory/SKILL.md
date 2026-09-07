---
name: repo-territory
description: Wide Scan step 1 - reads git history to build a territory map of the repository (active vs frozen areas, hotspots, quarterly breakdown, directory co-changes, shared-denominator files) and writes it to context/map/artifact-1-territory.md. Use this whenever the user asks "where does this project actually live", "what changes most often here", "where do I need to be careful in this legacy code", "hotspots", "co-changes", "what did they touch this year", and always as the first step of mapping an unfamiliar or legacy repository - before anyone starts reading code.
---

# Territory map - where the project actually lives

Before opening a single file, work out which areas are active and which are frozen. A directory tree shows a static snapshot ("what is here?"). Git history answers the harder question: "what here is important, connected, active and risky?"

Output goes to `context/map/artifact-1-territory.md`. It is a working note - input for a later synthesis, not the final map.

## The principle driving this step

CLI does its work **outside the context window**: a command walks thousands of commits and only a condensed result reaches the conversation. Your job is to interpret that evidence, not to read files. In this step you **do not open code**. If you catch yourself wanting to "just peek" at a file, write it down as a question for the Deep Focus stage instead.

Use the bundled `git-scan.sh` rather than improvising pipelines - it gives repeatable, pre-filtered results and applies the same noise filter on every run. Resolve its path once and reuse it, because you are running commands in the user's repository, not in the skill directory:

```bash
SCAN="${CLAUDE_PLUGIN_ROOT}/skills/repo-territory/scripts/git-scan.sh"
```

If `CLAUDE_PLUGIN_ROOT` is empty (the skill was installed standalone rather than via the plugin), locate `git-scan.sh` next to this SKILL.md and use that path instead. Invoke it with `bash "$SCAN" ...` - no `chmod` needed.

Full description of subcommands and environment variables: `references/git-recipes.md` - read it when you need to narrow the time window, change path collapsing depth, or add a project-specific noise filter.

## Step 1: where the work happens

```bash
bash "$SCAN" dirs      # top 10 directories (12-month window, depth 2 by default)
bash "$SCAN" files     # top 10 files
```

Noise (lockfiles, snapshots, generated files, localization, dist/build, binaries) is filtered out by default. If the result is too coarse - just `src/frontend` and `src/backend` - drop a level rather than guessing:

```bash
DEPTH=3 bash "$SCAN" dirs
DEPTH=3 bash "$SCAN" dirs src/backend   # scan within a single area
```

You want real hands-on areas of work, not the names of layers.

## Step 2: permanent core or seasonal campaign

A single ranking cannot tell a permanent center apart from an area where one hard bug got fixed for a quarter. Break the same data down by quarter:

```bash
bash "$SCAN" quarters
```

Each row is one directory with its yearly total and then every quarter in the window, zeros included - `src/campaign 12  2025-Q3:0  2025-Q4:0  2026-Q1:12  2026-Q2:0  2026-Q3:0` is unmistakably a campaign. The top N is chosen on the yearly total, so a year-round area cannot drop out of a single quarter's ranking and get mislabelled as seasonal.

Read the trend, not just the total: is the area's share growing, shrinking, or does it appear in one burst? An area present in every quarter is a `stable core` candidate. One visible in only one or two quarters is `seasonal` - and that is a different piece of information when judging the risk of a change.

Watch for a second distinction the raw change count cannot give you: is this area hot because an important feature runs through it, or because something keeps breaking there? Look for the signal in commit subjects (`git log --oneline -- <path>` filtered for `fix`), and if you cannot settle it, record it as an `unknown`.

## Step 3: what changes together

```bash
bash "$SCAN" cochange        # directory pairs in the same commits
TOP=15 bash "$SCAN" hub      # files touching many different areas at once
```

`cochange` reveals hidden adjacencies and cross-layer changes invisible in the directory tree: backend and frontend changing together is a signal of a contract between layers.

`hub` looks for the "shared denominator" - a single file changed alongside many areas. Usually that is a translations file, a config, a schema, a generated file, or a genuine architectural hub. **Tell those two cases apart**, because they weigh completely differently: a change "by regeneration" is cheap, hand-editing a hub is expensive. If a file looks generated, flag it explicitly in the artifact.

Commits touching more than 100 files (mass formatting, rename, migration) are skipped by default - otherwise they would swamp the co-change signal. Change the threshold with `MAXFILES`.

## Step 4: freshness check

History is evidence within a time window, not a snapshot of today. A file that churned all year may already have been deleted or moved. Before you build a conclusion on it:

```bash
printf 'src/a/foo.ts\nsrc/b/bar.ts\n' | bash "$SCAN" alive
```

Anything returned as `GONE` drops out of the conclusions or moves into the limitations section. This is one of the most common ways a legacy map starts lying.

## Step 5: write the artifact

Write `context/map/artifact-1-territory.md` in this shape:

```markdown
# Artifact 1 - Territory
Repo: <name> @ <HEAD sha>   Window: <SINCE>   Scan date: <YYYY-MM-DD>
Method: git log --no-merges, noise filter (lockfiles, generated, localization, snapshots)

## Key observations
3-5 sentences. Where work concentrates, what is surprising, what needs care.

## Active areas
| Area | Changes (12m) | Profile (stable/volatile/seasonal) | Evidence | What it means |

## Activity over time
Quarterly breakdown plus a one-sentence trend per area.

## Co-changes
| Pair/triple | Shared commits | Likely cause | Hand-edited or regenerated |

## Shared denominators
Files touching many areas, labelled: hub / config / generated.

## Freshness check
Paths checked with `alive`, with GONE flagged.

## Unknowns
What this method does not show - state it explicitly.
```

## What this step does NOT tell you

Write this into the artifact, otherwise someone (or an agent in a later session) will read activity as importance:

- history shows **where** the project was touched, not **why** and not whether it was right,
- a high change count can mean the product's center or a place where one bug was patched all year,
- co-changes show what changed together, but will **never** show a contract that *should* be kept in sync and is not (the classic: a backend model and its hand-maintained frontend counterpart),
- squash merges and mass renames distort the counters,
- an inactive area is not an unimportant one - it may be a stable core nobody touches.

Record each of these as an `unknown`, not as "no connections".

## Context window budget

This step should leave plenty of room for the work that follows. If you catch yourself pasting long raw logs into the conversation, lower `TOP` and work from summaries. What goes into the artifact is conclusions and short evidence trails, not dumps.

Once the artifact is saved, propose the next step: `repo-structure` (dependency graph) - ideally in a **fresh session** that starts by reading this artifact.
