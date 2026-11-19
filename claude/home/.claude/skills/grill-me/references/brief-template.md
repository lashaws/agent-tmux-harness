# Build brief template

Write for a reader with **zero context** — a fresh session, or the user in three weeks.
Delete sections that genuinely don't apply; never leave a heading with "TBD" where a stated
assumption would do.

```markdown
# <Feature name>

**Status:** brief — not yet implemented
**Date:** <YYYY-MM-DD>
**Grilled with:** /grill-me

## One-liner
<One sentence. What this is and who it's for.>

## Problem
<What breaks today, why now, who is hurting. 3-5 sentences, from the interview — not
invented.>

## Success looks like
- <Observable signal 1>
- <Observable signal 2>

## Non-goals
Explicitly out of scope for this version:
- <thing> — <why deferred>

## Context from the codebase
Facts established during recon, so the implementer doesn't rediscover them:
- Stack / framework / versions: <...>
- Relevant existing files: `path/to/file.ts:42` — <what it does and why it matters here>
- Patterns to follow: <error handling, validation, naming, test conventions>
- Prior art to reuse: <...>

## Decisions
| # | Decision | Chosen | Why | Rejected alternatives |
|---|----------|--------|-----|----------------------|
| 1 | <the fork> | <pick> | <reason from the interview> | <alt> — <why not> |

## Stated assumptions
Unresolved at brief time; implementer should proceed on these and flag if wrong:
- <assumption> — <what changes if it's wrong>

## Design

### Data shapes / contracts
```<lang>
// exact types, request/response bodies, schema, event payloads
```

### Flow
<Numbered walkthrough of the main path, end to end.>

### Implementation map
Concrete, file by file — this is what makes the one-shot work:
- `path/to/new-file.ts` — CREATE — <what goes in it, key functions, signatures>
- `path/to/existing.ts:120` — MODIFY — <exact change>
- `path/to/config.ts` — MODIFY — <register the new thing>

## Edge cases & failure modes
| Case | Expected behavior |
|------|-------------------|
| <empty input> | <...> |
| <dependency down> | <...> |
| <partial write> | <...> |
| <concurrent callers> | <...> |

## Migration & compatibility
<Existing data, existing callers, rollback path. "None needed" is a valid entry.>

## Verification
- [ ] <test to write — name the file and the case>
- [ ] <manual smoke check — exact command or click path>

Definition of done: <the concrete bar>

## Rollout
<Flag, first user, monitoring, what to watch.>

## Risks & open questions
| Risk | Impact | Mitigation / who decides |
|------|--------|--------------------------|

## Pre-mortem
Three weeks out, if this failed, the most likely causes:
1. <cause> — mitigated by <...>
2. <cause> — mitigated by <...>
```
