---
description: Audit the context architecture - has the root ballooned, what to cut, whether to split per module
---

Use the **context-review** skill to audit the context architecture in this repo.

I want:
- an inventory of instruction files with line counts and the date of their last real change,
- a list of rules to cut / move / keep, each with a one-sentence rationale,
- a maturity-ladder verdict: **stay on a single root** or **extract module X**, naming the
  specific signal that justifies it,
- a date for the next review.

Do not delete anything without my approval. If you see no signal for splitting, say so
plainly - even though I am probably expecting a "split it up" recommendation.
