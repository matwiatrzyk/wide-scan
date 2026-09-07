# git-recipes - `git-scan.sh` subcommands and supporting recipes

## Subcommands

| Command | Returns | Typical use |
|---|---|---|
| `dirs [path]` | top N directories by change count | first activity ranking |
| `files [path]` | top N files by change count | file-level hotspots |
| `quarters [path]` | full quarter matrix for the globally top N directories, zeros included | separating a stable core from a campaign |
| `cochange [path]` | directory pairs in the same commits | hidden adjacencies, cross-layer changes |
| `hub [path]` | files touching many different areas | shared denominator: config, schema, generated |
| `alive` (stdin) | whether paths still exist at HEAD | freshness check before drawing a conclusion |

Output is TSV: `count <TAB> item`. For `quarters`: `directory <TAB> total <TAB> YYYY-Qn:count ...` - one row per directory, every quarter in the window present, including zeros. The top N is picked on the yearly total, so a year-round area can never drop out of one quarter's ranking and masquerade as seasonal.

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `SINCE` | `12 months ago` | time window; `"6 months ago"`, `"2024-01-01"` |
| `TOP` | `10` | rows in the ranking |
| `DEPTH` | `2` | directory levels shown **below the scope path**, not from the repo root |
| `MAXFILES` | `100` | larger commits are skipped in `cochange` and `hub` |
| `NOISE` | - | extra noise regex, appended to the default |

Examples:

```bash
SINCE="6 months ago" TOP=15 bash "$SCAN" dirs
DEPTH=1 bash "$SCAN" dirs packages/api   # DEPTH counts levels below packages/api
NOISE='(^|/)fixtures/|\.golden$' bash "$SCAN" files
MAXFILES=40 bash "$SCAN" cochange     # repo with frequent mass changes
```

## Default noise filter

Filtered out: lockfiles (npm/pnpm/yarn/poetry/cargo/go/composer/bundler), `.env*`, the directories `node_modules|dist|build|out|vendor|target|__snapshots__|.venv|coverage`, snapshots and binaries (`.snap .svg .png .jpg .woff .map .min.js .min.css`), localization (`i18n/ locales/ translations/ .po .mo`), generated files (`.generated. _pb2.py .pb.go .g.dart .d.ts`).

If the project has its own codegen convention (e.g. `src/api/__generated__/`), add it via `NOISE` - otherwise the ranking shows the code generator instead of human work.

Note the reverse risk too: `.d.ts` is filtered by default, but in some TypeScript projects those files are hand-maintained contracts. If that is the case here, override the filter rather than concluding the area is quiet.

## Supporting recipes (run these by hand when a thread needs pulling)

Is the area hot from development or from repairs:

```bash
git log --since="12 months ago" --no-merges --oneline -- <path> \
  | grep -Eic '(^|\s)(fix|hotfix|bug|revert|patch)'
git log --since="12 months ago" --no-merges --oneline -- <path> | wc -l
```

How many different people touched the area (concentrated or distributed knowledge):

```bash
git log --since="12 months ago" --no-merges --pretty='%an' -- <path> | sort -u | wc -l
```

When a file was last alive:

```bash
git log -1 --date=short --pretty='%h %ad %s' -- <path>
```

History across a rename (git loses the trail by default):

```bash
git log --follow --oneline -- <path> | head -30
```

Whether a mass commit in the window is skewing the stats:

```bash
git log --since="12 months ago" --no-merges --pretty='%h %s' --shortstat \
  | awk '/files? changed/ && $1 > 200 {print prev, $0} {prev=$0}'
```

Excluding a path from the scan (e.g. the whole test layer, when only production code matters):

```bash
git log --since="12 months ago" --no-merges --pretty=format: --name-only \
  -- . ':(exclude)**/*test*' ':(exclude)e2e/' | sort | uniq -c | sort -rn | head
```

## Pitfalls

- **Squash merges** collapse dozens of commits into one - the area looks calmer than it was.
- **Renames** reset a file's counter; a directory can look new while the code is old.
- **A monorepo with a single `apps/`** needs a higher `DEPTH`, otherwise everything lands in one node. When you pass a scope path, `DEPTH` is measured from that scope, and the script prints the effective depth on stderr - read that line, it tells you whether the grouping is at a useful level.
- **Shallow clones** have no full history. The script warns about this on stderr; if it does, record it as a limitation of the map rather than ignoring it.
- **`--since` filters by commit date**, which for rebased or cherry-picked work can differ substantially from when the code was written.
