# Design Frameworks Reference

Detailed reference for page-level design decision frameworks. Read the relevant section when the core process in SKILL.md calls for it.

## Jobs To Be Done (JTBD)

Originated by Tony Ulwick (1991, "Outcome Driven Innovation"), popularized by Clayton Christensen. Core insight: users don't buy products — they "hire" them to accomplish a job.

### Job Statement Format

```
When [situation/context], I want to [motivation/action], so I can [desired outcome].
```

**Write these instead of user stories when deciding page content.** Job stories remove the persona and add situational context, which prevents building for hypothetical archetypes.

### Applying to Page Content

For every element you consider placing on a page:

1. **What job is the user hiring this page to do?** Not "what data do we have" but "what outcome does the user need."
2. **What is the trigger?** When does the user arrive? What just happened? What are they doing next?
3. **What are the outcome metrics?** Users have 50-150 distinct outcome statements per job. Identify which this page must satisfy.
4. **Does this element help complete the job?** Every UI element must trace back to a job. If it doesn't, cut it.

### The Four Forces of Progress

Evaluate whether to add an element by measuring four forces:

| Force | Direction | Question |
|-------|-----------|----------|
| **Push** (current pain) | Toward change | What frustration drives users to this page? |
| **Pull** (new solution) | Toward change | What's the attraction of having this? |
| **Anxiety** (new complexity) | Against change | What uncertainty or complexity will this introduce? |
| **Inertia** (habit) | Against change | What existing behavior patterns will users default to? |

**Include only when Push + Pull > Anxiety + Inertia.**

### Intercom's 5-Step Job Stories Process

1. Start with the high-level job
2. Identify smaller supporting jobs
3. Observe how people currently solve the problem
4. Create job stories exploring causality, anxieties, and motivations
5. Design solutions that directly resolve the identified job

---

## Kano Model

For prioritizing which content elements belong on a page. Uses a questionnaire to classify features into categories.

### The Five Categories

| Category | Definition | User reaction |
|----------|-----------|---------------|
| **Must-be** | Expected; absence causes dissatisfaction, presence doesn't increase satisfaction | "Of course it has that" |
| **Performance** | Satisfaction scales proportionally with investment | "More is better" |
| **Attractive** | Unexpected; creates disproportionate delight | "Wow, I didn't expect that" |
| **Indifferent** | Users don't care either way | No reaction |
| **Reverse** | Users prefer it NOT be present | "I wish this weren't here" |

### The Questionnaire

For each candidate element, ask two questions:

1. **Functional:** "How would you feel if this page HAD [feature]?"
2. **Dysfunctional:** "How would you feel if this page DID NOT have [feature]?"

Responses: Like it / Expect it / Neutral / Can tolerate it / Dislike it

### Evaluation Table

Cross-reference functional (rows) × dysfunctional (columns):

| | Like | Expect | Neutral | Tolerate | Dislike |
|---|---|---|---|---|---|
| **Like** | Q | A | A | A | P |
| **Expect** | R | Q | I | I | M |
| **Neutral** | A | I | I | I | M |
| **Tolerate** | A | I | I | Q | M |
| **Dislike** | P | M | M | M | Q |

M=Must-be, P=Performance, A=Attractive, I=Indifferent, R=Reverse, Q=Questionable

### Prioritization Order

1. Include ALL Must-be elements (table stakes)
2. Add Performance elements to the extent resources allow
3. Include select Attractive elements for differentiation
4. Cut Indifferent and Reverse elements

**Kano decay:** Attractive features become Performance, then Must-be over time. Re-evaluate periodically.

---

## User Story Mapping (Jeff Patton)

### Three-Level Hierarchy

| Level | Definition | Example |
|-------|-----------|---------|
| **Activities** | High-level user goals | "Monitor system health" |
| **Steps** | Sequential subtasks within each activity | "Check error rates" |
| **Details** | Granular interactions | "Filter by time range" |

Layout: left-to-right for sequence, top-to-bottom for priority.

### The Backbone

Top row = Activities and Steps in the order users perform them. This becomes your navigation/page structure skeleton.

### Release Slicing (Walking Skeleton)

Draw horizontal lines across the map:
- **Slice 1 (MVP):** Minimum details under each step for end-to-end functionality
- **Slice 2:** Enhanced details for the most important steps
- **Slice 3+:** Progressively richer functionality

### Translation to Page Design

1. Map the user's journey on this page (what first, second, third?)
2. For each step, brainstorm all possible details/features
3. Stack details vertically by priority under each step
4. Draw the MVP line — above goes in V1
5. **Steps → page sections/areas. Details → individual elements.**

---

## Object-Oriented UX (OOUX)

For determining what objects and their properties belong on a page.

1. **Define Objects** — Core "things" in the user's domain (clusters, databases, queries, users)
2. **Map Relationships** — How objects relate to each other
3. **Identify Attributes** per object:
   - Core content (primary information)
   - Metadata (sortable/filterable properties)
   - Nested objects (related objects displayed inline)
4. **CTA Inventory** — All possible actions per object, with conditions and priority
5. **Validate with users** before designing interactions

Prevents the mistake of designing actions before determining what the user is acting on.

---

## Information Architecture

### LATCH (Richard Saul Wurman)

Every set of information can ONLY be organized in one of five ways:

1. **Location** — Geographic or spatial position
2. **Alphabet** — Alphabetical ordering
3. **Time** — Chronological sequence
4. **Category** — By topic, type, or attribute
5. **Hierarchy** — By magnitude, importance, or rank

Pick whichever best serves the user's primary task.

### Abby Covert's Seven-Step IA Process

1. **Identify the mess** — What's confusing? What information exists?
2. **State your intent** — What should this page communicate?
3. **Face reality** — Constraints (technical, political, content availability)
4. **Choose a direction** — Select an organizational approach (LATCH)
5. **Measure the distance** — How far is current state from goal?
6. **Play with structure** — Experiment with arrangements and hierarchies
7. **Prepare to adjust** — Build in flexibility; plan for iteration

### IA Anti-Patterns (NNGroup)

- **No organizing principle** — Pages as disconnected collections
- **Missing overview pages** — Jumping to items without context
- **Over-classification** — Multiple overlapping dimensions confuse users
- **Hidden navigation** — Options users can't see "might as well not exist"
- **Unfamiliar terminology** — Invented labels harm findability

---

## Mental Model Alignment

### Core Principle

"A mental model is what the user believes about the system." Designs that violate expectations create confusion.

### Validation Methods

| Method | What it reveals | When to use |
|--------|----------------|-------------|
| **Card sorting** | How users group content elements | Early — before wireframing |
| **Tree testing** | Whether users can find items in proposed hierarchy | After initial IA, before visual design |
| **Think-aloud test** | Where mental model mismatches occur | On prototypes |

### Two Strategies

**A: Conform to existing mental models** (preferred) — use card sorting, tree testing, and familiar patterns from tools users already know.

**B: Improve users' mental models** (fallback for novel interfaces) — clearer labeling, onboarding walkthroughs, contextual help.

---

## Progressive Disclosure

NNGroup recommends a maximum of two levels:

**Level 1 (primary):** Most important, frequently-needed content. Loads by default.
**Level 2 (secondary):** Detailed breakdowns, filters, drill-downs. Available on explicit request.

Rules:
- Mechanism to access Level 2 must be **obvious** (visible buttons/links)
- Labels must set expectations about what the user will find
- All commonly-needed functions must be on Level 1
- Never hide critical actions behind progressive disclosure
