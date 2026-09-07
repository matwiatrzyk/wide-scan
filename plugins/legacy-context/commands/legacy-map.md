---
description: Full Wide Scan of an unfamiliar repo - territory, structure, contributors, synthesized into context/map/repo-map.md
argument-hint: [scope path, e.g. src or packages/api]
---

Build a project map for this repository. Scope: $ARGUMENTS (empty = whole repo).

Work through this **in order**, using the matching skill at each stage and saving the
artifact before moving on:

1. Check whether `context/map/` exists. If not, use the **context-scaffold** skill.
2. **repo-territory** → `context/map/artifact-1-territory.md`
3. **repo-structure** → `context/map/artifact-2-structure.md`
4. **repo-contributors** → `context/map/artifact-3-contributors.md`
5. **repo-map** → `context/map/repo-map.md`

Rules for this session:

- Do not read code in steps 2-4. You are gathering evidence from CLI, not building an
  understanding of the system.
- After each step, show me a short summary and **ask whether to continue**. Each step
  costs context window; I want to see where the budget goes.
- If the context window gets tight, say so plainly and suggest I run the next step in a
  fresh session - the on-disk artifacts exist precisely for that.
- A label without evidence is a guess. Anything no command confirms goes to `unknowns`.
