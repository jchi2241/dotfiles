---
name: ux-design
description: Use when designing a new page or feature, deciding what content belongs on a screen, writing UI copy or microcopy, wireframing, approaching an overview/dashboard/settings/detail page, or when the user asks how to structure an interface.
---

# UX Design & Copywriting

Structured methodology for approaching new pages, features, and interfaces. Applies industry frameworks to decide **what** belongs, **how** to organize it, and **how to write** the copy.

## Core Process

Four phases, always in order. Never skip to layout before completing Define.

### Phase 1: Define (before any design tool)

1. **State the page's job.** Complete: "A user comes to this page to ___." One sentence. If you can't, the page tries to do too much — split it.

2. **Write JTBD statements** for every user scenario:
   ```
   When [situation/trigger], I want to [motivation], so I can [outcome].
   ```
   See [design-frameworks.md](references/design-frameworks.md) § JTBD for the full method including the Four Forces test.

3. **Inventory all candidate content.** List every element the page *could* include: data, controls, navigation, status, help text.

4. **Prioritize with the Kano filter:**
   - **Must-be:** Include all (table stakes — absence causes dissatisfaction)
   - **Performance:** Include to the extent resources allow (more = better)
   - **Attractive:** Select 1-2 for differentiation (delight, but decays over time)
   - **Indifferent/Reverse:** Cut
   See [design-frameworks.md](references/design-frameworks.md) § Kano for the questionnaire method.

5. **Apply progressive disclosure.** Split surviving content into:
   - **Level 1 (primary):** Visible without interaction — the most critical, frequently-needed elements
   - **Level 2 (secondary):** Available on explicit request (click/expand/tab) — mechanism must be obvious

### Phase 2: Structure (low-fidelity)

6. **Choose an organization scheme (LATCH).** Every set of information can only be organized by one of:
   - **L**ocation | **A**lphabet | **T**ime | **C**ategory | **H**ierarchy (magnitude/importance)
   Pick whichever best serves the user's primary task.

7. **Apply the Inverted Pyramid.** Rank content into three tiers:
   - **Tier 1 (the lead):** If users only glance once, they see this
   - **Tier 2 (supporting):** Secondary details ranked by audience relevance
   - **Tier 3 (background):** Context, historical data — can be cut without losing the core message

8. **Match the page type pattern.** See [ui-patterns.md](references/ui-patterns.md) for layout frameworks:
   - Dashboard/overview | Detail | List/table | Settings | Onboarding | Empty state

9. **Group with Gestalt principles:**
   - **Proximity** (most powerful): close items = related. Use whitespace as primary organizer.
   - **Similarity:** Shared visual characteristics = functionally related
   - **Common region:** Cards/borders reinforce grouping when spacing alone isn't enough
   - **Continuity:** Aligned elements suggest sequence

10. **Design for scanning pattern:**
    - **F-pattern** for content-heavy pages (articles, data tables): front-load headings with keywords, key info in first two lines, bold key terms
    - **Z-pattern** for sparse pages (login, landing): logo top-left, CTA top-right, conversion action bottom-right

### Phase 3: Write the Copy

11. **Apply the 4 C's to every string:**

    | Principle | Test question | Fix |
    |-----------|--------------|-----|
    | **Clear** | Would a first-time user understand this without context? | Plain language, no jargon, no double negatives |
    | **Concise** | Can any word be cut without losing meaning? | Front-load key info, cut filler ("please note that", "in order to") |
    | **Constructive** | Does this help the user move forward? | Tell users what TO do, not just what went wrong |
    | **Conversational** | Does it sound natural read aloud? | Contractions, second person, active voice |

12. **Write for the user's mental model, not the system model.** Label things by what they mean to the user, not what they are in the database.

13. **Apply element-specific microcopy rules:**

    | Element | Key rule | Example |
    |---------|----------|---------|
    | Buttons | Verb describing the outcome | "Create account" not "Submit" |
    | Errors | What happened + how to fix | "That email is registered. Try signing in." |
    | Empty states | Guide toward first action | "No projects yet. Create one to get started." |
    | Tooltips | Explain why, not just what | "Archiving keeps it searchable but removes it from your inbox." |
    | Confirmation dialogs | State the consequence | "Delete this project? This can't be undone." |
    | Loading states | Set expectations | "Crunching your numbers..." |

    See [copywriting-frameworks.md](references/copywriting-frameworks.md) for voice/tone frameworks (NNGroup 4 dimensions, Mailchimp model) and persuasive frameworks (AIDA, PAS, BAB, FAB) for onboarding/upgrade flows.

### Phase 4: Validate

14. **Squint test.** Blur the design. Does the intended hierarchy still emerge?
15. **Keyboard walkthrough.** Tab through every interactive element. Is focus order logical?
16. **Cognitive load audit.** For each element: "Does this earn its screen space? Can it be removed, combined, or deferred?"
17. **NNGroup top mistakes sweep:** Missing feedback? Inconsistent labels? Bad error messages? Missing defaults? Unlabeled icons? Tiny click targets? Modal overuse? Destructive actions near confirm?
18. **Read all copy aloud.** If it sounds stilted, rewrite it.

## Quick Decision Aids

### "Does this belong on the page?"

Apply the **Four Forces** test:

| Force | Direction | Question |
|-------|-----------|----------|
| Push (current pain) | → Add | What frustration drives users here? |
| Pull (new solution) | → Add | What's the attraction of having this? |
| Anxiety (complexity) | ← Remove | What uncertainty does this introduce? |
| Inertia (habit) | ← Remove | Will users default to old behavior instead? |

**Include only when Push + Pull > Anxiety + Inertia.**

### "How do I prioritize competing elements?"

Use a **2×2 prioritization matrix**:
- Axis 1: User impact (how many users, how often)
- Axis 2: Importance when needed (how critical in the moment)
- Top-right quadrant goes on the page. Bottom-left gets cut.

## References

- [design-frameworks.md](references/design-frameworks.md) — JTBD (full method + Four Forces), Kano model (questionnaire + evaluation table), User Story Mapping, OOUX, mental model alignment
- [copywriting-frameworks.md](references/copywriting-frameworks.md) — 4 C's deep dive, Voice & Tone (NNGroup 4 dimensions, Mailchimp, Shopify Polaris), microcopy catalog, persuasive frameworks (AIDA, PAS, BAB, FAB, SCQA)
- [ui-patterns.md](references/ui-patterns.md) — Layout patterns per page type, Atomic Design, visual hierarchy techniques, accessibility (POUR), responsive/mobile-first, Gestalt principles
