# classification - how to label modules on the map

A bare list of modules is not enough. A good map needs labels that support decisions: where to read next, what not to touch by accident, which areas are just background.

This is not an academic architecture taxonomy. These are working labels that follow from evidence.

## Label axes

| Axis | Values | Question it answers |
|---|---|---|
| **role** | core / supporting / peripheral | is the module close to the product's main value |
| **depth** | deep / shallow | does it hold real logic, or is it a thin entry layer |
| **change profile** | stable / volatile / seasonal | does it change regularly, almost never, or in campaigns |
| **blast radius** | load-bearing / contained | do many parts of the system depend on it or its contracts |
| **sensitivity** | high / medium / low | how carefully changes here must be approached |
| **layer** | contract / implementation | does it expose a contract or consume one |

## Four questions that drive the classification

### 1. Is this core?

Core is **not** "the biggest folder" or "the nicest name". Core is the area the product's main value or a critical operational flow runs through: authentication, payments, data, messaging, orders, permissions, synchronization, billing.

Evidence can be: an entry point, a public contract, an endpoint, a command, a job, a domain model, frequent use by other modules, or a link to the main user flow.

### 2. What is its coupling?

This is not an abstract judgment of "good/bad coupling", but the question: **what might move when I touch this?**

- **incoming** - how many places depend on this module; many → a contract change has wide blast radius,
- **outgoing** - how many places this module depends on; many → brittle to neighbors' changes,
- **contract** - does it expose types, an API, events, a data schema or a shared package used by other layers,
- **runtime** - dependencies invisible in imports: feature flags, DI, configuration, queues, webhooks, reflection, dynamic imports, codegen,
- **co-change** - frequent co-occurrence in commits; a signal for the map, not a diagnosis.

### 3. What do the tool's metrics say?

Tools like dependency-cruiser do not say whether a module is "business-important". They measure the import graph.

| Signal | Practical meaning | How to use it in the map |
|---|---|---|
| **Ca** (afferent) | how many modules depend on this one | high → a contract or load-bearing element |
| **Ce** (efferent) | how many modules this one depends on | high → a module assembling many external dependencies |
| **instability** = Ce/(Ca+Ce) | outgoing relative to total | low with high Ca → stable core; high → thin adapter or orchestration |
| **cycles** | import cycles between files or modules | caution-zone candidate: tangled boundaries |
| **orphan / leaf** | no dependents or no dependencies | periphery, dead code, or a separate entry point - needs verification |

### 4. What matters in static analysis of legacy code?

- **entry points**: endpoints, pages, CLI commands, jobs, event handlers, webhooks,
- **dependency direction**: who imports whom, and whether layers are inverted,
- **contracts**: public types, DTOs, schemas, shared packages, API clients,
- **graph centers**: nodes with many edges in or out,
- **cycles**: places where module boundaries are tangled,
- **adapters and thin entry points**: files that look important but only delegate onward,
- **gaps in the method**: dynamic imports, DI, reflection, runtime configuration, generated code, feature flags.

## Recording format

Do not put a raw metrics table in the map. Write down **the decision the metric supports**:

```yaml
Module: server/public
role: supporting / contract layer
evidence:
  - high incoming coupling in the import graph (Ca=41)
  - frequent co-changes with backend and frontend (18 shared commits / 12 months)
inference:
  - changing public types can ripple through several layers
caution:
  - before a larger change, check usages in webapp and server/channels
unknowns:
  - the static graph shows neither runtime dependencies nor API compatibility on the client side
```

This format - `evidence → inference → caution → unknowns` - matters more than the specific labels. It forces a split between **evidence** and **interpretation**, and that is exactly the line along which legacy maps usually fall apart.

## Questions worth asking during classification

- Which modules are probably core, but the evidence is weak? What command or additional source could verify it?
- Which entry points are thin, and where does the real logic start? (Do not pick the first file just because it has a good name.)
- Where might the static graph lie through runtime coupling: DI, dynamic imports, feature flags, configuration, webhooks, codegen?
- Which labels are only hypotheses? Mark them `unknown` or `needs verification`.

At this stage, **do not diagnose hotspots and do not propose refactors**. This is the map's legend, not a quality analysis.
