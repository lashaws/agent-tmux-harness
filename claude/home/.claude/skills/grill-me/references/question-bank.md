# Question bank

Raw material, not a script. Pick the probes that bite for *this* problem, rewrite them in
the user's own vocabulary, and attach concrete options drawn from the recon.

A probe is only worth asking if a different answer produces different code.

## 1. Problem
- What happens today when someone hits this? Walk me through the current workaround.
- Why now — what changed? (new customer / it broke / it's blocking something else / itch)
- Who complains about this, and how often?
- If you did nothing for six months, what actually goes wrong?

## 2. User & job
- Who is on the other end — you, a teammate, a customer, a script?
- What are they doing in the 60 seconds before they reach this? And right after?
- How many of them, how often? (once a day vs. 1000/sec is a different system)
- What do they do today instead?

## 3. Success
- Two weeks after shipping, what do you look at to know it worked?
- What's the observable signal — a metric, a log, a support ticket that stops arriving?
- What would "technically shipped but useless" look like here?

## 4. Boundary
- Name three things this explicitly does *not* do in v1.
- What's the smallest version you'd still be happy to ship?
- Which part are you most tempted to gold-plate? (then: cut it or keep it?)
- Is this a permanent thing or a stepping stone you'll throw away?

## 5. Prior art
- Is there something in this repo that already does 70% of this?
- Is there a library for this, and why aren't we using it?
- Has this been tried here before and abandoned? Why?

## 6. Shape
- What's the entry point — HTTP route, CLI command, cron, event, UI action?
- What's the exact data going in and coming out? (use `preview` with two candidate shapes)
- Where does state live, and who owns it?
- Sync or async? What's the latency budget?
- New module, or extend an existing one? (name the specific file from recon)

## 7. Tradeoffs
- Present the 2-3 real forks as previewed options with consequences, e.g.:
  - store denormalized vs. join at read time
  - poll vs. webhook vs. queue
  - one big endpoint vs. several small ones
  - config file vs. env vars vs. database row
  - build it vs. adopt a dependency
- For the chosen fork: what would have to become true for you to regret this?

## 8. Constraints
- Hard deadline, or done-when-done?
- Who maintains this in six months — you, or someone who's never seen it?
- Any auth/permission boundary this crosses? Who's allowed to call it?
- Does this touch PII, secrets, money, or anything you can't un-send?
- Cost ceiling (compute, API calls, per-request tokens)?
- Does it have to work offline / in CI / on someone else's machine?

## 9. Failure modes
- The dependency this calls is down for 10 minutes. What should users see?
- It half-succeeds — three of five records written. What now?
- Is the operation safe to retry? Is it idempotent, or do we need a key?
- Who gets woken up when it breaks, and what do they look at first?
- Should a failure here be loud (throw) or quiet (degrade)?

## 10. Edge cases
- Zero items. One item. Ten million items.
- Two of these running at once on the same record.
- Input from a hostile or just careless caller.
- Unicode, timezones, daylight saving, leap seconds, `null` vs. `""` vs. missing.
- The user hits back / refreshes / double-clicks mid-operation.
- Permission denied halfway through.

## 11. Migration & compat
- Is there existing data in the old shape? Who backfills it?
- Who calls the thing you're about to change? Are they in this repo?
- What's the rollback if this is wrong in production?
- Can old and new coexist, or is it a hard cutover?

## 12. Verification
- What test would have caught the bug you're most afraid of?
- Unit, integration, or "I'll click it once"? (all three are legitimate answers)
- What's the manual smoke check after deploy?
- What does "done" mean — merged, deployed, or someone else used it successfully?

## 13. Rollout & ops
- Behind a flag, or straight out?
- Who's the first user, and do they know?
- What gets logged, and would you be able to debug this from logs alone at 2am?

## 14. Risks
- What's the part you're least sure about?
- What's the one unknown that, resolved first, would change everything downstream?
- If this fails, will it fail loudly on day one or quietly in month three?
- Rate your confidence in the trickiest piece — and what would raise it?

## Pre-mortem prompts (Phase 3, run on yourself)
- Three weeks out, this shipped and it was a mistake. What's the headline?
- What did we build that nobody used?
- What did we not ask about that turned out to be load-bearing?
- What did the user assume was obvious that isn't in the brief?
