# Dependency graph tooling per stack

The pattern is universal: **static import graph → DOT/JSON/Markdown → synthesis**. Most of these tools emit DOT (the Graphviz format), so in a polyglot monorepo you can generate several maps and synthesize them together. The question stays the same: "is this module a real dependency center, or just a thin entry point?"

## JS / TypeScript - dependency-cruiser (default choice)

```bash
npm install --save-dev dependency-cruiser
npx depcruise --init                       # generates .dependency-cruiser.js with rules
```

Core invocations:

```bash
# Cycles in a chosen area, human-readable output
npx depcruise src/app --include-only "^src" --output-type err-long

# Coupling metrics (Ca, Ce, instability) as a table
npx depcruise src --include-only "^src" --output-type metrics

# JSON for further processing
npx depcruise src --include-only "^src" --output-type json > /tmp/dep.json

# Mermaid (renders directly inside repo-map.md)
npx depcruise src --include-only "^src" --output-type mermaid

# High-level architecture view
npx depcruise src --include-only "^src" --output-type archi > /tmp/archi.dot

# Collapse to folders, then render
npx depcruise src --include-only "^src" --collapse "^src/[^/]+" \
  --output-type dot | dot -T svg > context/map/graph.svg
```

Cycle detection is configured by the `no-circular` rule in `.dependency-cruiser.js`. Layer boundaries are enforced with `forbidden` rules using `from`/`to` - so the same tool answers "does layer X import Y?".

Supports JS, TS, CoffeeScript, LiveScript and ES6/CommonJS/AMD modules. Requires the project toolchain (`typescript` installed for TS).

JS/TS alternatives:
- **madge** - fast cycle detection and a simple graph: `npx madge --circular --extensions ts,tsx src`. With TypeScript it needs `tsconfig` and resolvers wired up.
- **skott** - modern analyzer, handles `tsconfig.paths` aliases better, which simpler mappers frequently lose.

## Python - Tach, pydeps

```bash
pip install tach pydeps
tach show                       # module graph (DOT); tach show --web for a browser view
tach check                      # verify boundaries declared in tach.toml
pydeps package --show-dot --max-bacon 2 --cluster
pydeps package --show-cycles    # cycles only
```

Tach additionally lets you **declare** module boundaries and check them in CI - useful if a refactor follows the map.

## Go - goda, go mod graph

```bash
go install github.com/loov/goda@latest
goda graph ./... | dot -T svg > graph.svg
goda graph -cluster ./...        # groups related packages
go mod graph                     # textual module graph (modules, not packages)
```

`goda` does not detect module boundaries automatically - you supply the layer split yourself.

## Java - jdeps, Maven Dependency Plugin

```bash
jdeps --dot-output ./out -verbose:class target/app.jar
mvn dependency:tree -DoutputType=dot -DoutputFile=deps.dot
```

`jdeps` **cannot see** dependencies via reflection or `Class.forName` - record that as an `unknown`, because in older Java applications (Spring, DI, ServiceLoader) that is often half the real graph.

## C# / .NET - dotnet-deptree, NDepend

```bash
dotnet tool install -g dotnet-deptree
dotnet-deptree -f dot -o deps.dot
```

NDepend gives a graph plus a dependency matrix, but it is commercial.

## Swift - SwiftPM, spmgraph

```bash
swift package show-dependencies --format dot
swift package show-dependencies --format json
```

## Kotlin / Gradle

```bash
./gradlew generateDependencyGraph      # vanniktech/gradle-dependency-graph-generator
```

`modules-graph-assert` enforces dependency rules as part of the build.

## When there is no tool for your stack

Do not pretend the absence of a graph means the absence of dependencies. Fallback:

```bash
# Rough import graph via rg - imprecise, but still evidence
rg -n --no-heading '^\s*(import|from|require|use|#include)' src \
  | sed 's/:.*//' | sort | uniq -c | sort -rn | head -30
```

And **record in the artifact** that this layer has no dependency graph. That is an `unknown`, not "no connections" - the distinction matters for everyone who reads the map later.

## Limits shared by all of these tools

No static graph will show dependencies injected at runtime: dynamic require/import, dependency injection, feature flags, environment configuration, queues and events, webhooks, reflection, code generated at build time. These gaps are **part of the map, not a flaw in it** - provided they are written down as `unknowns`.
