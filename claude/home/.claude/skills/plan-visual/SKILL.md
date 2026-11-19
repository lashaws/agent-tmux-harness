---
name: plan-visual
description: Make plans, roadmaps, rollouts and epic breakdowns ordered by dependency tiers, never by dates or durations, and give big plans an HTML visual to review. Use whenever you are making or presenting a plan, roadmap, phased rollout, epic breakdown or migration plan, or Lashaw says "plan", "roadmap", "visualize the plan", "break this down". Lashaw rejects calendar-dated plans.
---

# Plan-visual: tiers, not dates

Lashaw rejects plans organised by date, week, quarter, sprint or duration. Order by what depends on what.
This applies to every plan you write or present, in chat, an issue or a file.

## 1. Build the order

1. List the items. Write each as one action with a checkable outcome.
2. For each item, name the items it needs (its prerequisites). Nothing else orders it.
3. Group into tiers: **Tier 1 has no prerequisites; Tier N depends only on items in earlier tiers.**
   An item sits in the lowest tier its prerequisites allow. Items in a tier run in parallel.
4. Under each item, mark what it **unblocks**.
5. Mark items that need Lashaw (a sign-in, MFA, a decision they reserve) distinctly. Try the step yourself
   first; mark it only if something refuses you. Use the walkthrough skill for sign-ins.
6. No dates, no durations, no "week 2", no "Q3", no effort estimates, anywhere. If an item waits on the world
   (a vendor, a calendar event), it is a Tier 1 external-dependency item, not a date.
7. A cycle means you split an item wrongly; split until the graph is acyclic.

Small plans (under about 6 steps): the tiered list in chat is enough:
`Tier 1: A, B / Tier 2: C (needs A, B) / ...`

## 2. The HTML visual (about 6+ steps, or anything Lashaw must approve)

Write ONE self-contained HTML file: no external CSS, JS, fonts or images; it must work offline.
- Tiers as columns (rows on narrow screens), items as cards, each card showing id, one-line action,
  `Needs:` and `Unblocks:` hints, and a distinct style plus label for items that need Lashaw.
- Light and dark through `prefers-color-scheme`. Check contrast in both.
- No dates anywhere, including the footer and the file's metadata text.

Start from the template for the project:
- Project has its own brand template: use it. In trueage read `docs/brand/README.md` first and start from
  `docs/brand/template.html` (Steward Pillars brand).
- Otherwise copy `~/.claude/skills/plan-visual/template.html` (a working 3-tier, 6-card example) and replace
  its content; keep its structure and styles.

## 3. Save, open, hand over

Where to save, first match wins:
1. The project's convention: life-wiki `derived/views/`; trueage `~/work/trueage-notes/`.
2. Otherwise `<repo>/docs/plans/<slug>.html`.

Then run `open <file>` and give Lashaw a markdown link to the file and its folder, e.g.
`[plan.html](file:///abs/path/plan.html) ([folder](file:///abs/path/))` (`%20` for spaces).
In the reply, show the tiers as a short list too; the file is the review copy, not the only copy.

## 4. Check before you hand over

- `grep -niE '20[0-9]{2}-|january|monday|week [0-9]|Q[1-4]' <file>` returns nothing.
- Every item appears once, every `Needs:` names an item in an earlier tier.
- The file loads with no console errors.
