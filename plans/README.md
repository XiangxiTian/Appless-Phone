# Waterfall animation plans

Commit baseline: 26710e22

| Plan | Title | Severity | Status | Depends on |
| --- | --- | --- | --- | --- |
| 001 | Make Waterfall layers reversible | MEDIUM | DONE | — |
| 002 | Unify Waterfall press feedback | MEDIUM | DONE | 001 |
| 003 | Preserve feedback with reduced motion | MEDIUM | DONE | 001, 002 |

## Recommended execution order

1. Execute 001 first because it introduces the existing-project motion tokens and corrects layer interruption.
2. Execute 002 next because it reuses --ease-out for selected controls.
3. Execute 003 last because its reduced-motion overrides target the final selectors from 001 and 002.

Keep all three changes inside HtmlAggregateSearchHomeRenderer.ets and its existing renderer tests. Do not touch Waterfall scrolling, provider state, iframe behavior, full-screen geometry, or host bridge code.
