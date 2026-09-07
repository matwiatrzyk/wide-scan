---
name: repo-contributors
description: Wide Scan step 3 - builds a contributor map for the sensitive areas of a repository: who actually worked on a module in the last 12 months, what TYPE of problem they specialize in (migrations, permissions, protocols, edge cases, emergency fixes) and who to ask before making a change. Filters out bots and agent commits. Writes context/map/artifact-3-contributors.md. Use this whenever the user asks "who should I ask about this code", "who knows this area", "who wrote this", "tribal knowledge", "contributor map", "who has context on this module", or as the third step of mapping a legacy repository.
---

# Contributor map - who knows what, and what to ask them

This is the layer most often skipped in legacy analysis, and skipping it is a mistake. Code can be read. Decisions, context and edge cases usually cannot - those live in the heads of the people who touched the area.

The question this step answers: **"who do I ask before making a change someone already attempted a year ago?"**

Output: `context/map/artifact-3-contributors.md`.

## Step 1: pick areas, do not scan the whole repo

Read `context/map/artifact-1-territory.md` and `context/map/artifact-2-structure.md` if they exist, and pick the **top 5 areas** that genuinely warrant talking to a human. Typical candidates are places where:

- activity intersects auth, data, payments, migrations, caching, integrations or runtime configuration,
- the graph showed a cycle or high Ca (a change has wide blast radius),
- history suggests the same problem being fixed repeatedly,
- the layer has no dependency graph at all (a human is then the only source).

Scanning the whole repo for authors produces a ranking of the busiest people in the company - not an answer to who to ask about a specific module.

## Step 2: who worked on the area

Use the bundled `git-authors.sh`. Resolve its path once - you are running commands in the user's repository, not in the skill directory:

```bash
AUTHORS="${CLAUDE_PLUGIN_ROOT}/skills/repo-contributors/scripts/git-authors.sh"
bash "$AUTHORS" top    src/payments      # contributor ranking for the area
bash "$AUTHORS" topics src/payments      # commit subjects per author (classification input)
bash "$AUTHORS" recent src/payments      # recent commits: sha, date, author, subject
bash "$AUTHORS" spread src/payments      # knowledge concentration / bus factor
```

If `CLAUDE_PLUGIN_ROOT` is empty (standalone install), locate `git-authors.sh` next to this SKILL.md and use that path.

Bots and automation are filtered out by default (`dependabot`, `renovate`, `github-actions`, `semantic-release`, crowdin/weblate, `*[bot]`, `noreply@`), as are agent commits (`claude`, `codex`, `copilot`) **without clear human authorship**. If the project has its own CI account, add it:

```bash
BOTS='deploy-svc|jenkins' bash "$AUTHORS" top src/payments
```

Also check whether agent commits are authored by a human with a `Co-authored-by` trailer - the ranking is then correct, but it is worth noting:

```bash
git log --since="12 months ago" --grep='Co-authored-by' --pretty='%an %s' -- <path> | head
```

## Step 3: thematic classification - this is where the value is

A raw commit count is a dry list of "who touched the code most". A useful map answers a different question: **who worked on which type of problem in this sector**.

Read the commit subjects (`topics`) and group each person's activity into categories that are actually visible in the data. Common axes:

- data and schema migrations,
- permissions, roles, auth,
- protocols, integrations, API contracts,
- performance and caching,
- edge cases and emergency fixes (`fix`, `hotfix`, `revert`),
- refactors and code moves,
- tests and test infrastructure.

For each person write one or two sentences: **what they are deep in** and **what specifically is worth asking them**. Do not list every author - 1-2 candidates per zone is enough.

If commit subjects are useless (`update`, `fix`, `wip`), say so plainly and base the classification on the file paths that person touched:

```bash
git log --since="12 months ago" --author="<name>" --pretty=format: --name-only -- <path> \
  | grep -v '^$' | sort | uniq -c | sort -rn | head -15
```

## Step 4: knowledge concentration

```bash
bash "$AUTHORS" spread <path>
```

This reports unique authors, total commits and the top author's share. One person holding 60%+ is a **bus factor** signal - record it as a risk of the area, not just as a fact. Ten people with a handful of commits each means something different: probably nobody holds the full picture, and talking to a person will not be enough - you will need to read PRs.

## Step 5: what to read before changing anything

For each zone point to 1-3 concrete trails, not generalities:

```bash
git log --since="12 months ago" --merges --oneline -- <path> | head -10   # PRs
git log --since="12 months ago" --grep='revert' -i --oneline -- <path>    # reverted attempts
git log -1 --pretty='%H%n%s%n%n%b' <sha>                                  # decision write-up
```

Reverted changes are especially valuable: they are the record of an attempt that already failed once.

## Step 6: write the artifact

```markdown
# Artifact 3 - Contributors
Repo: <name> @ <sha>   Window: 12 months   Date: <YYYY-MM-DD>
Method: git log --no-merges per area, bot and agent-commit filter

## Selected areas and why
5 areas plus a one-sentence rationale drawn from artifacts 1 and 2.

## Who to ask - per area
| Area | Person | Commits (12m) | What they are deep in | What specifically to ask |

## Knowledge concentration
Per area: unique authors, top author's share, bus factor assessment.

## Trails to read before changing
PRs, reverts, commits with decision write-ups - each with a sha and a one-line "why this matters".

## Unknowns
```

## What this step does NOT tell you

State this explicitly in the artifact:

- commit history shows **who touched** the area - not who formally owns it, not whether they still work here, not whether the decisions in those PRs still hold,
- it is an entry point to a conversation and to reading PRs, **not a list of authorities**,
- `git blame` answers a different question ("who changed this line?"); the contributor map answers "who holds context for this area and what type of problem do they specialize in",
- squash merges attribute an entire PR to one person, losing co-authors,
- renames break authorship history; when in doubt use `git log --follow`.

## Privacy

This is data about real people. Keep in the artifact **the names as they appear in the repo history, and nothing more** - no email addresses, no cross-referencing with external sources, no performance judgments. The artifact exists so someone can ask a colleague a smart question, not to build a profile.

Once the artifact is saved, propose `repo-map` - the final synthesis.
