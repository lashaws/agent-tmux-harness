---
name: grill-me
description: >
  Deep interview-driven ideation. Use when the user wants to think through an idea,
  feature, or project before building it — and wants to be pushed, not just planned for.
  Triggers on "/grill-me", "grill me on", "interview me about", "help me think through",
  "poke holes in this idea", "I want a really thorough plan", "make this one-shottable".
  Runs adaptive rounds of probing multiple-choice questions, forces the unmade decisions
  into the open, runs a pre-mortem, then writes a self-contained build brief that a fresh
  session with zero context can implement in one shot.
  Do NOT use for small well-specified tasks, or when the user just says "make a plan"
  and wants to move fast — that's plan mode.
---

# Grill Me

Plan mode asks what you want and plans it. This asks what you *haven't thought about* yet,
and refuses to write the plan until the load-bearing decisions are actually made.

**North star:** the artifact at the end is a brief so complete that a fresh session — no
memory of this conversation — can build the thing correctly on the first attempt. Every
question you ask is in service of that. If an answer wouldn't change what gets built, don't
ask it.

## Phase 0 — Recon before you open your mouth (silent, ~2 min)

Never spend a question on something the repo can tell you. Before the first question:

- Read the user's one-liner. Identify the domain and the likely blast radius.
- If in a repo: find the code this would touch, the patterns already in use (framework,
  state management, test runner, error conventions), and any prior art to reuse or copy.
  Use `Explore` or a few greps — timebox it, don't audit the codebase.
- Check for a CLAUDE.md, README, or existing plans/docs on this topic.
- Check memory for prior context on this project.

Carry forward every constraint you found. These become *stated facts* in the brief, and
they sharpen your questions: "You've got Zod schemas everywhere else — reuse for this
endpoint's input, or is this the place to switch?" beats "How should we validate input?"

## Phase 1 — Reflect the frame back

Two to four sentences, no more:

1. What you understand them to be asking for.
2. What you already know from recon (so they see you did the work).
3. The 3-5 unknowns you're about to grill on.

This is their chance to correct the framing before you spend rounds on the wrong thing.
Then go straight into Round 1 — do not ask permission to begin.

## Phase 2 — The rounds (the core)

Each round is **one `AskUserQuestion` call with 2-4 questions**, themed together.
Aim for **3-6 rounds total**. Between rounds, keep a private ledger: DECIDED / OPEN /
ASSUMED.

### Question craft — this is where the skill lives

- **Options must be real forks.** Each option is a concrete, defensible path with its
  tradeoff spelled out in the description. Ban filler like "Yes / No / Not sure",
  "Simple / Complex", "Whatever you think". If you can't write three real options, you
  don't understand the problem well enough to ask yet — go read more code.
- **Lead with a recommendation.** When you have a view, make it option 1 and mark it
  `(Recommended)`. Ambivalence wastes their time; they can always pick another.
- **Use `preview` for anything with a shape.** API payloads, schema options, file layouts,
  UI arrangements, state machines, config formats. Side-by-side comparison of two concrete
  artifacts produces better decisions in five seconds than a paragraph of prose does in a
  minute. This is the single highest-leverage move in the skill.
- **Adapt, don't recite.** Derive each round from the last round's answers. If an answer
  exposes a contradiction, a much bigger scope, or a bad assumption — abandon the plan for
  the round and chase that instead. That's the whole point.
- **Push once on the load-bearing calls.** Don't accept the first answer on the decision
  that everything else hangs off. Follow up with the consequence: "You picked per-tenant
  keys — so what happens when a tenant needs to rotate mid-request?" Ask it as a question
  with options, never as a lecture.
- **Every round, one question they didn't see coming.** Hunt for the thing that blows the
  plan up in week two, not week one.

### Coverage checklist

Cover these or consciously skip them. Skipping is fine — silently leaving a hole is not.
See `references/question-bank.md` for concrete probes under each.

1. **Problem** — what breaks today, why now, who is hurting
2. **User & job** — who touches it, what happens immediately before and after
3. **Success** — the observable signal that it worked
4. **Boundary** — explicit non-goals; v1 vs. later
5. **Prior art** — what to reuse, extend, or deliberately not copy
6. **Shape** — architecture, data model, contracts, interfaces
7. **Tradeoffs** — the 2-3 genuine forks, and the pick with its reason
8. **Constraints** — perf, cost, security, auth, compliance, deadline, who maintains it
9. **Failure modes** — partial failure, bad input, downstream outage, retries
10. **Edge cases** — empty, huge, concurrent, offline, permission-denied, duplicate
11. **Migration & compat** — existing data, existing callers, rollback path
12. **Verification** — tests, manual check, the definition of done
13. **Rollout & ops** — flags, monitoring, who gets it first
14. **Risks** — what would kill this; which unknown must be resolved first

### Reading the room

Terse answers, repeated "Other: whatever you think", or "just go" = stop grilling. Write
the brief immediately with the remaining unknowns listed as **explicit stated assumptions**
rather than blocking on them. A brief with five named assumptions beats a fourth round the
user didn't want.

## Phase 3 — Adversarial pass (you run this on yourself, no questions yet)

Before writing anything:

- **Pre-mortem.** It's three weeks later and this shipped badly. Write the top 3 causes.
  Any cause tracing back to a decision nobody made → that's one more round of grilling.
- **The 10x-simpler check.** Is there a version that's a tenth of the work and gets 80% of
  the value? If yes, you must surface it — as an option, not a sermon — and let them reject
  it on the record. Their rejection reason goes in the brief.
- **Coherence sweep.** Do any two decisions contradict each other? Ask.

## Phase 4 — Write the brief

Write to `docs/plans/<slug>.md` if the repo has such a directory, otherwise the scratchpad;
tell the user the path either way. Use `references/brief-template.md`.

The test for every section: **could someone with zero context build this from the brief
alone?** Include the recon facts, the file-level implementation map, the concrete data
shapes, and the rejected alternatives with reasons — a fresh session that doesn't know what
was already ruled out will re-propose it.

In chat, give a compressed summary: the decisions made, the assumptions stated, and the
riskiest open item. Do not paste the whole brief back.

## Phase 5 — Handoff

Offer three paths and take direction: build it now in this session, start a fresh session
pointed at the brief (best for a true one-shot), or stop here with the brief on disk.

## Rules of engagement

- Sharp and concrete, never rude or performatively skeptical. You're a good staff engineer
  in a whiteboard session, not a hazing ritual.
- Max 4 questions per call. Batch them; don't drip one at a time.
- Never ask what you can look up. Never ask what wouldn't change the build.
- Never write the plan before the interview. Never end without the written artifact.
