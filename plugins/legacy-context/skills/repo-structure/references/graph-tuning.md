# graph-tuning - taming an over-dense graph

A raw graph of a whole module almost always comes out as a **hairball**: hundreds of edges, unreadable, useless for decisions. Paste that image into a report and you get decoration, not a working tool.

The rule: a graph answers **one** question. Pick the lever that fits the question.

| Goal | Lever | What it does |
|---|---|---|
| Top-down view | `rankdir=TB` (via `reporterOptions.dot.theme.graph.rankdir`, or `sed 's/rankdir="LR"/rankdir="TB"/'`) | vertical hierarchy instead of horizontal |
| Collapse detail into structure | `--collapse "^src/[^/]+"` | nodes become folders, not individual files |
| Upstream only (who depends on X) | `--reaches "X"` | every module leading to X |
| Downstream only (what X depends on) | `--focus "X" --focus-depth N` | X and its neighborhood to depth N |
| Ready-made architecture view | `--output-type archi` | reporter designed for architecture diagrams |
| Hubs only | no native flag - compose `--metrics` with `--include-only` | show only high-degree nodes |
| Drop external packages | `--exclude 'node_modules'` | removes react, redux, lodash and friends |
| Layout engine | `dot` (hierarchical) rather than `fdp`/`sfdp` | hierarchical DAG instead of a point cloud |

## Trap: doNotFollow is not exclude

The default `doNotFollow: 'node_modules'` **does not remove** packages from the graph - it only stops descending into them, and the leaf nodes still get drawn and clutter the render. To make them disappear, use `exclude` (in the config or as a flag):

```bash
npx depcruise src --exclude 'node_modules|\.test\.|\.stories\.|__snapshots__|\.d\.ts$' \
  --output-type dot | dot -T svg > graph.svg
```

Apply the same pattern to tests, stories, snapshots and generated code.

## A sequence that usually works

1. Collapse to folders: `--collapse "^src/[^/]+"` - see the layer layout.
2. Find the suspicious node (high Ca, or part of a cycle).
3. Narrow: `--focus "<that node>" --focus-depth 2`.
4. Only now render to SVG.

If the graph is still unreadable, that means the question is too broad - not that you need a bigger canvas.

## Work at the level of intent, not syntax

Nobody needs to memorize these flags. The user speaks plainly - "the graph is too detailed, show only the hubs", "collapse to folders", "flip it vertical", "show only what depends on the payments module" - and you translate that into a concrete invocation. Then show the result and correct in the same direction until the graph answers the question.

## Rendering without Graphviz

If `dot` is not installed (`which dot`), do not silently install it. Alternatives:

```bash
npx depcruise src --output-type mermaid          # paste mermaid straight into markdown
npx depcruise src --output-type dot > graph.dot  # let the user render it locally
```

Mermaid has the advantage of rendering directly inside `repo-map.md` - which is where the map actually gets read.
