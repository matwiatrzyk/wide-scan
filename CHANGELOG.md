# Changelog

All notable changes to `wide-scan` are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
adheres to [Semantic Versioning](https://semver.org/).

Release notes on GitHub are generated from the entries below, so every release
needs its section here before `scripts/release.sh` will let it through.

## [Unreleased]

### Added

-

## [1.0.1] - 2026-09-07

### Fixed

- `check-version.sh` used `readarray`, which needs bash 4. macOS ships
  bash 3.2, so validation — and therefore `release.sh` — failed there.

## [1.0.0] - 2026-09-07

First release. Six skills for entering an unfamiliar repository, distributed
through two channels from one source of truth.

### Added

- `context-scaffold` — creates `context/` and a lean root `AGENTS.md`.
- `repo-territory` — git-history hotspots, quarterly breakdown, directory
  co-changes and hub files, with a noise filter for lockfiles, snapshots,
  localization and generated code.
- `repo-structure` — static dependency graph per stack, cycles, blast radius.
- `repo-contributors` — authors per area with a bot and agent-commit filter,
  plus a `spread` subcommand reporting knowledge concentration.
- `repo-map` — synthesis of the three working artifacts into a decision-grade
  `context/map/repo-map.md`.
- `context-review` — audit of `AGENTS.md` against a maturity ladder.
- Commands `/legacy-map`, `/ctx-init`, `/ctx-review`.
- npm distribution: `postinstall` installs skills to `.agents/skills/` (read by
  Cursor and Codex) and links them into `.claude/skills/` for Claude Code.
- `scripts/uninstall.mjs` — removes exactly the paths recorded in
  `.wide-scan.json`, leaving anything it did not create alone.
- Claude Code marketplace manifest, so the same tag serves both channels.

[Unreleased]: https://github.com/matwiatrzyk/wide-scan/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/matwiatrzyk/wide-scan/releases/tag/v1.0.1
[1.0.0]: https://github.com/matwiatrzyk/wide-scan/releases/tag/v1.0.0