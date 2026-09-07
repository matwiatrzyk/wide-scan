# wide-scan

A set of skills for entering **large and legacy repositories**. Instead of asking an agent to "read the whole repo and explain the architecture" (which does not fit in the context window, and produces a flat summary even when it does), you gather cheap deterministic signals from the CLI and ask the agent to **interpret evidence**.

The result is a `context/` directory holding a decision-grade project map an agent can load in a later session.

## Install

Two channels, one source of truth, one version number.

### npm (any tool)

```bash
npm install --save-dev @matwiatrzyk/wide-scan
```

The package is public, so nothing to configure — but the scope has to be pointed
at GitHub Packages. Add this to `.npmrc` in the consuming project:

```
@matwiatrzyk:registry=https://npm.pkg.github.com
```

Everything else keeps resolving from public npm.

A `postinstall` script lays the artifacts out where each tool actually reads them:

| Path | Read by |
|---|---|
| `.agents/skills/<name>/` | Cursor and Codex, natively |
| `.claude/skills/<name>` | Claude Code (symlink to the canonical copy) |
| `.claude/commands/*.md` | Claude Code slash commands |
| `.cursor/commands/*.md` | Cursor commands |

Narrow the targets if you only use one tool:

```bash
WS_TARGETS=claude npm install --save-dev @matwiatrzyk/wide-scan
```

Update with `npm update @matwiatrzyk/wide-scan` — the installer replaces
its own files and leaves everything else alone. Remove cleanly with:

```bash
npm run uninstall:artifacts && npm uninstall @matwiatrzyk/wide-scan
```

### Claude Code marketplace

```
/plugin marketplace add matwiatrzyk/wide-scan
/plugin install legacy-context@wide-scan
```

Pin a version with `matwiatrzyk/wide-scan@v1.0.0`. Convenient if Claude
Code is the only tool in play; the npm route is the one that survives a change of
tooling.

## What's inside

| Skill | Fires when | Produces |
|---|---|---|
| `context-scaffold` | "set up context", starting work in a new repo | `context/` + a lean root `AGENTS.md` |
| `repo-territory` | "where does this project live", "hotspots", "what changes here" | `context/map/artifact-1-territory.md` |
| `repo-structure` | "what depends on what", "cycles", "blast radius" | `context/map/artifact-2-structure.md` |
| `repo-contributors` | "who should I ask about this code" | `context/map/artifact-3-contributors.md` |
| `repo-map` | "build a project map", "summarize the analysis" | `context/map/repo-map.md` |
| `context-review` | "AGENTS.md is too long", "the agent ignores my rules" | report + maturity-ladder verdict |

Commands: `/legacy-map [scope]`, `/ctx-init`, `/ctx-review`.

Skills fire **on their own** when the conversation matches — the commands are for when you want to walk the whole flow deliberately, stage by stage. Command frontmatter (`$ARGUMENTS`, `argument-hint`) is Claude Code syntax; in other tools the same files still work as plain prompts.

## The flow

```
/ctx-init                    →  context/ + AGENTS.md
   ↓
repo-territory (git)         →  artifact 1: where the project lives
   ↓
repo-structure (graph)       →  artifact 2: what depends on what
   ↓
repo-contributors (git)      →  artifact 3: who to ask
   ↓
repo-map (synthesis)         →  repo-map.md: risk zones + first day
```

Each step writes its artifact to disk **precisely so** the next one can start in a fresh session with a clean context window. On a large repo that is not an optimization — it is the condition for the analysis finishing at all.

## What is deterministic and what is interpretation

The skills ship two scripts that do the heavy lifting **outside the context window**:

- `repo-territory/scripts/git-scan.sh` — hotspots, quarterly breakdown, directory co-changes, hub files, and a check of whether a path still exists. With a built-in noise filter (lockfiles, snapshots, localization, generated code, `dist/`) and skipping of mass commits.
- `repo-contributors/scripts/git-authors.sh` — authors per area with a bot and agent-commit filter, plus a `spread` subcommand reporting knowledge concentration (bus factor).

Only the condensed result reaches the conversation. The agent **interprets smaller, better data** — it does not read hundreds of files.

## Design assumptions

**A label without evidence is a guess.** Every template in these skills enforces the `evidence → inference → caution → unknowns` format. That is the line along which legacy maps usually fall apart: interpretation recorded as fact.

**Gaps in the method are part of the map, not a flaw in it.** A layer with no dependency graph is an `unknown`, not "no connections". A static graph will never show DI, feature flags, webhooks or codegen — and the map has to say so, otherwise the next session reads silence as absence of risk.

**The map should be decision-grade, not complete.** The test: does a new developer know, after 15 minutes, where things live, what is dangerous and where to start.

## Requirements

- `git` (mandatory — without history only `context-scaffold` and `context-review` work),
- `bash`, `awk`, `sort` (standard on macOS/Linux; on Windows use WSL or Git Bash),
- Node 18+ for the npm install route,
- optional: `dependency-cruiser`/`madge` for JS/TS, per-stack equivalents (documented in `skills/repo-structure/references/stacks.md`), `graphviz` for SVG rendering.

The skills **install nothing without asking** and **never overwrite existing instruction files**. The installer applies the same rule: a path that already exists and is not recorded in its manifest is left untouched.

## Releasing

```bash
# write the CHANGELOG entry first, then:
./scripts/release.sh 1.1.0
```

That bumps the version in all four manifests, validates them, tags and pushes. The tag triggers one workflow that publishes both the GitHub Release and the npm version. `scripts/check-version.sh` runs on every push and refuses a release where nothing under `plugins/` or `scripts/` actually changed.

## Repo layout

```
package.json                     npm artifact definition + publishConfig
.claude-plugin/marketplace.json  Claude Code marketplace manifest
plugins/legacy-context/
├── .claude-plugin/plugin.json
├── commands/                    legacy-map, ctx-init, ctx-review
└── skills/
    ├── context-scaffold/
    ├── repo-territory/          + scripts/git-scan.sh, references/git-recipes.md
    ├── repo-structure/          + references/stacks.md, graph-tuning.md
    ├── repo-contributors/       + scripts/git-authors.sh
    ├── repo-map/                + references/classification.md, assets/repo-map-template.md
    └── context-review/
scripts/
├── install.mjs                  postinstall: artifacts → tool directories
├── uninstall.mjs                removes exactly what the manifest records
├── check-version.sh             version + manifest + skill validation
└── release.sh                   bump, validate, tag, push
```

## License

MIT — see [LICENSE](./LICENSE).
