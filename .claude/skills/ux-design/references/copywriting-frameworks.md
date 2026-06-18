# Copywriting Frameworks Reference

Detailed reference for UX writing and copywriting frameworks. Read the relevant section when the core process in SKILL.md calls for it.

## The 4 C's (Deep Dive)

The consensus UX writing quality heuristic. Apply to every piece of interface text.

### Clear

- User understands the meaning immediately, no ambiguity
- Plain language; avoid jargon, technical terms, double negatives
- Write at a grade-school reading level (target 7th grade)
- Test: "Would a first-time user understand this without context?"
- Write for the user's mental model, not the system model
- Front-load information-carrying words (not filler like "Welcome to our...")

### Concise

- Fewest words possible without losing meaning — every word earns its place
- Eliminate filler: "please note that", "in order to", "it is important to"
- Buttons: "Save" over "Save your changes"
- Apply the **Jenga approach** (Shopify): remove every word that isn't structurally necessary. If meaning holds without it, cut it.
- Front-load key information for scanners

### Constructive

- Every piece of text helps the user move forward
- Critical in error states: instead of "Invalid input", write "Enter a date in MM/DD/YYYY format"
- Tell users what TO do, not just what went wrong
- Frame negatives as next steps
- Empty states should guide toward first action, not just describe emptiness

### Conversational

- Write the way a helpful human would speak
- Use contractions ("don't" not "do not")
- Second person ("you")
- Active voice
- Read it aloud — if it sounds stilted, rewrite it
- Natural language over robotic phrasing: "Done! Your file is saved." not "Operation completed successfully."

### Marketing Variant (4 C's: Clear, Concise, Compelling, Credible)

Used for in-app marketing, upgrade prompts, onboarding value propositions — not primary product UI. "Compelling" = resonates and motivates. "Credible" = claims backed by evidence.

---

## Voice & Tone

### The Foundational Distinction

**Voice** = product's consistent personality. Stays the same everywhere.
**Tone** = how that personality adapts to context. Shifts based on user's emotional state and situation.

### NNGroup's Four Dimensions of Tone

Use these as slider scales to define your product's target position:

1. **Formal ←→ Casual** — Professional/institutional vs. informal/conversational
2. **Serious ←→ Funny** — Straightforward vs. humor-infused
3. **Respectful ←→ Irreverent** — Deferential vs. convention-challenging
4. **Matter-of-Fact ←→ Enthusiastic** — Dry/neutral vs. energetic/excited

Test with users via Likert scales and product-reaction surveys. Tone measurably impacts brand perception and usability.

### Notable Design System Approaches

**Mailchimp** (industry gold standard for voice/tone docs):
- Four pillars: Plainspoken, Genuine, Translators (demystify complexity), Dry Humor (straight-faced, never condescending)
- Core rule: "Always more important to be clear than entertaining"
- Assess reader's emotional state and adjust tone accordingly

**Microsoft:**
- Warm and relaxed — natural, grounded in everyday conversation
- Crisp and clear — write for scanning first, reading second
- Ready to lend a hand — anticipate needs, offer info at the right time

**Shopify Polaris:**
- Words are "an essential part of the design"
- Targets 7th-grade reading level
- Uses contractions, starts sentences with verbs
- The Jenga approach — remove every element that isn't load-bearing

**IBM Carbon:**
- "Engages the thinker by speaking like the thinker"
- Confident but not boastful; persuasive, not poetic
- Tone adapts: error messages are terse; onboarding is explanatory

### Tone Variation by Context

| Context | Tone adjustment |
|---------|----------------|
| Success/completion | Warm, brief confirmation + next step |
| Error/failure | Empathetic, specific, action-oriented |
| Onboarding | Welcoming, explanatory, encouraging |
| Destructive action | Serious, precise, consequence-focused |
| Empty state | Helpful, guiding, action-oriented |
| Loading/waiting | Light, expectation-setting |

---

## Microcopy Catalog

### Error Messages (NNGroup Framework)

Three requirements:

1. **Visibility** — Display adjacent to the problem; combine text + color + icon (never color alone); modals for critical barriers, toasts for minor issues; avoid premature validation
2. **Communication** — Plain language, specific problem, constructive remedy, positive tone (no blame words like "invalid"), skip humor
3. **Efficiency** — Prevent common mistakes proactively, preserve user input, suggest fixes, link to help resources

### Element-Specific Rules

| Element | Principle | Good example | Bad example |
|---------|-----------|-------------|-------------|
| **Button labels** | Verb describing outcome | "Create account" | "Submit" |
| **Error messages** | What happened + how to fix | "That email is registered. Try signing in." | "Invalid input" |
| **Empty states** | Guide toward first action | "No projects yet. Create one to get started." | "No results found" |
| **Tooltips** | Explain why, not just what | "Archiving keeps it searchable but removes it from inbox." | "Archive item" |
| **Loading states** | Set expectations or reduce perceived wait | "Crunching your numbers..." | "Loading..." |
| **Success messages** | Confirm + suggest next step | "Payment received. Confirmation email on its way." | "Success" |
| **Placeholder text** | Show format, not labels | "MM/DD/YYYY" | "Enter date" |
| **Confirmation dialogs** | State consequence, label destructive action clearly | "Delete this project? Can't be undone. [Cancel] [Delete project]" | "Are you sure? [OK] [Cancel]" |

### NNGroup's Microcontent Principles

- Must function standalone (out of context)
- Specificity over generality
- Front-load keywords
- No puns in functional text

---

## Persuasive Frameworks

Use these for onboarding, upgrade prompts, feature adoption, and in-app marketing — not primary product chrome.

### AIDA (Attention → Interest → Desire → Action)

Grab attention with a compelling headline, build interest with the key benefit, create desire with social proof or specificity, present a clear CTA.

**SaaS example:** "Your trial ends in 3 days [A]. Keep access to advanced analytics [I] that helped you find 12 insights last week [D]. Upgrade now [A]."

### PAS (Problem → Agitate → Solution)

Identify a pain point, intensify it, present the resolution.

**Product example (empty state):** "You're missing insights from your data [P]. Every day without tracking means lost opportunities [A]. Connect your data source to start seeing trends in minutes [S]."

### BAB (Before → After → Bridge)

Paint the current struggle, show the transformed state, position the product as the bridge.

**Product example (upgrade prompt):** "Before: manually exporting reports every Monday. After: automated reports in your inbox. Bridge: Set up scheduled exports in Settings."

### FAB (Feature → Advantage → Benefit)

Translate technical features into user value. Critical for tooltips, settings descriptions, and feature announcements.

**Example:** "Two-factor authentication [F] adds a second verification step [A] so only you can access your account [B]."

### SCQA (Situation → Complication → Question → Answer)

From Barbara Minto's Pyramid Principle (McKinsey). Useful for help docs, changelogs, complex feature explanations.

Establishes context before presenting the solution.

---

## Cross-Cutting Principles

These appear across all frameworks regardless of methodology:

1. **Plain language always wins** — target 7th-grade reading level
2. **Active voice, second person** — universal across Google, Microsoft, Mailchimp, Shopify, Apple
3. **Front-load information** — most important word/concept first, because users scan
4. **Write for user's mental model** — label by meaning to user, not database field name
5. **Every string moves the user forward** — if it doesn't help complete a task, cut it
6. **Test by reading aloud** — quality gate advocated by Shopify, Mailchimp, and Microsoft
7. **Tone adapts; voice stays constant**
