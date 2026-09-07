---
name: repo-structure
description: Wide Scan step 2 - builds a static dependency graph of the repository (dependency-cruiser for JS/TS, equivalents for Python, Go, Java, C#, Swift, Kotlin) and turns it into a decision-grade report: entry points, import cycles, layer boundaries, Ca/Ce/instability coupling metrics, testability risks and blast radius. Writes context/map/artifact-2-structure.md. Use this whenever the user asks "what depends on what", "dependency graph", "import cycles", "blast radius", "do the layers hold their boundaries", "what breaks if I change this", "dependency-cruiser", "depcruise", "madge", or as the second step of mapping an unfamiliar repository.
---

# Structure map - how this thing is built

Git history tells you where to look. This step answers: **what actually depends on what**. The graph has to show blast radius, local centers and thin entry points - not a list of imports.

Output: `context/map/artifact-2-structure.md`.

## Step 0: start from the territory, not from the whole repo

If `context/map/artifact-1-territory.md` exists, **read it first**. A graph of an entire repo almost always comes out as a hairball: hundreds of edges, unreadable, useless for decisions. The question worth asking is narrowed: "are the areas that came out as most active real centers, thin entry points, or contracts between layers?"

If that artifact does not exist, agree on the scope with the user or pick the 3-6 largest source areas - and say plainly that the scope is a hypothesis.

## Step 1: identify stack and tooling

Before installing anything, check what the project already has:

```bash
ls package.json pyproject.toml go.mod pom.xml build.gradle* *.csproj Package.swift 2>/dev/null
cat package.json | grep -A20 '"scripts"'           # a graph script may already exist
ls .dependency-cruiser.* depcruise* madge* 2>/dev/null
cat tsconfig.json | grep -A15 '"paths"'            # path aliases break resolution
```

Tool selection per stack, flags and output formats: **read `references/stacks.md`**. Do not guess the syntax - each of these tools has its own conventions, and used wrongly it will quietly return an empty graph.

**Always confirm installs with the user** before running them (it is a change to their repo). For JS/TS the default is:

```bash
npm install --save-dev dependency-cruiser
```

Important: dependency-cruiser analyzes code import by import, so it needs the project's toolchain (a completed `npm install`, `typescript` present for TS projects). Without it you get an empty or drastically incomplete graph - and an empty graph is easy to mistake for "no dependencies".

## Step 2: Markdown first, not a picture

Do not start with SVG. At this stage you want a short answer: where the code is tangled, whether the layers hold their boundaries, and which places will hurt at test time. Markdown is easy to read, easy to paste into the artifact and easy to refine in conversation. Save JSON for comparing runs over time, and SVG for the final presentation.

Run three analyses, each as a separate question:

**A. Cycles in active areas.** Restrict yourself to the areas from artifact 1 - you do not want an exhaustive list of everything in the repo. For each cycle, explain **in plain language** why it makes change harder: where a change in one file forces a change in another that imports it back.

**B. Layer boundaries.** Check the direction of imports between layers (types/contracts as the foundation, client below UI, no imports "upward"). Interpret this against activity: do the frequently changed places use those layers predictably, or are there imports that will surprise someone mid-change?

**C. Testability risks.** Which places will be hard to test in isolation because they drag in many imports, global state, an API client or shared utils. Be concrete: where heavy mocking will be needed, where an integration test fits better, and where a change naturally ends in an e2e test.

For each of these, use a table with the columns: **Area | What I found | Evidence from the tool | Why it matters for a change | Link to artifact 1 | What to check next**.

The "Evidence" column is mandatory. A label without evidence is a guess - and a legacy map full of guesses is worse than no map, because it creates false confidence.

## Step 3: coupling metrics

`--metrics` turns "this feels tightly coupled" into an actual coordinate:

| Signal | Meaning | How to read it |
|---|---|---|
| **Ca** (afferent) | how many modules depend on this one | high → a contract or a load-bearing element; changes have wide blast radius |
| **Ce** (efferent) | how many modules this one depends on | high → a module assembling other people's dependencies; brittle to neighbors' changes |
| **instability** = Ce/(Ca+Ce) | outgoing relative to total | low with high Ca → stable core; high → thin adapter or orchestration |
| **cycles** | import cycles | candidate caution zone; boundaries are tangled |
| **orphan / leaf** | no dependents or no dependencies | periphery, dead code, or a separate entry point - needs verification |

Do not paste the raw metrics table into the artifact. Write down **the decision the metric supports**.

## Step 4: render the graph only after selection

Once the Markdown analysis shows what matters for decisions, render **one** subgraph answering **one** question: one cycle, one layer boundary, or one fragment with testability risk.

Techniques for taming an over-dense graph (`--collapse`, `--focus`, `--reaches`, `rankdir`, excluding `node_modules`): **`references/graph-tuning.md`**.

One trap worth internalizing right now: the default `doNotFollow: 'node_modules'` **does not remove** packages from the graph - it only stops descending into them, and the leaf nodes still clutter the render. Removing them is what `--exclude` is for.

## Step 5: write the artifact

```markdown
# Artifact 2 - Structure
Repo: <name> @ <sha>   Tool: <name + version>   Scope: <analyzed paths>
Date: <YYYY-MM-DD>   Toolchain ready: yes/no

## Key observations
3-5 sentences.

## Entry points
Thin entry points vs real centers of logic - with evidence, not from the filename.

## Cycles
Table plus a one-sentence "why this hurts when changing".

## Layer boundaries
Which hold, which leak, with a concrete import as evidence.

## Metrics and blast radius
Load-bearing modules (high Ca), brittle modules (high Ce), each with a decision.

## Testability risks
Where mocking, where integration, where e2e.

## Unknowns and gaps in the method
```

## What a static graph does NOT show

This is the most important section of the artifact, because it is where a legacy map most often lies:

- **runtime coupling**: DI, dynamic imports, reflection, feature flags, configuration, queues, webhooks, codegen - none of it appears in an import statement,
- **intent**: `shared/utils` used by eight modules may be a deliberate cross-cutting concern or a junk drawer nobody could name; the graph does not settle that,
- **a cycle** may be a real architectural problem or an artifact of the build configuration,
- **a layer with no graph** (different language, part of the stack with no tooling) is an `unknown`, **not** "no connections". State it explicitly - otherwise the next session reads silence as absence of risk,
- misconfigured path aliases silently drop imports; if `tsconfig.paths` exists and the graph looks suspiciously sparse, verify resolution before drawing any conclusion.

Once the artifact is saved, propose `repo-contributors` - ideally in a fresh session.
