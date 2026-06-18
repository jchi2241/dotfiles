---
name: writing-skills
description: Use when creating new skills, editing existing skills, or verifying skills work before deployment
---

# Writing Skills

Guide for creating, testing, and iterating on skills. Covers the full lifecycle: drafting, self-review, user-driven testing, and iterative improvement.

## Creation Workflow

### Phase 1: Gather Intent

Before writing, understand:
1. **What** should this skill enable an agent to do?
2. **When** should it trigger? (user phrases, contexts, symptoms)
3. **What type** is it? (technique, pattern, reference, discipline -- see Skill Types below)
4. **What does the agent NOT already know?** Only add context it lacks.

If prior conversation contains a workflow worth capturing, extract the steps, corrections, and domain knowledge from the conversation history.

### Phase 2: Draft the Skill

Write the SKILL.md with frontmatter (`name`, `description`) and body. Key constraints:
- `name`: max 64 chars, lowercase letters/numbers/hyphens
- `description`: max 1024 chars, starts with "Use when...", third person, no workflow summary (see CSO section)
- Body: under 500 lines. Use separate files for heavy reference (>100 lines).
- One level of file references max (SKILL.md -> reference.md, never deeper).

### Phase 3: Self-Review

After writing, re-read the SKILL.md as if seeing it cold. Check:
- [ ] Description triggers on the right queries and ONLY describes when to use (not what it does)
- [ ] Body contains only information the agent doesn't already have
- [ ] Instructions are actionable, not narrative
- [ ] Consistent terminology throughout
- [ ] Under 500 lines; heavy reference in separate files
- [ ] No time-sensitive information

### Phase 4: Test and Iterate

**Ask the user:** "Want to test this skill before we finalize?"

If yes, follow the iteration loop:

1. **Create 2-3 test prompts** -- realistic things a user would actually say that should trigger this skill. Share them with the user for approval.
2. **Run each prompt in a fresh chat** with the skill attached. Observe:
   - Did the skill trigger? (description quality)
   - Did the agent follow the instructions correctly? (body quality)
   - Did it miss anything or go off-track? (gaps)
   - For discipline skills: did it resist pressure? (see Bulletproofing section)
3. **Collect feedback** from the user on each test result.
4. **Revise the skill** based on feedback. Focus on:
   - Generalizing from specific failures (don't overfit to test cases)
   - Explaining the WHY behind instructions, not adding rigid MUSTs
   - Removing content that didn't pull its weight
   - Closing loopholes found during testing (for discipline skills)
5. **Re-test** with the same prompts + any new ones. Repeat until the user is satisfied or feedback is empty.

**For discipline-enforcing skills**, also run pressure scenarios (see Testing Discipline Skills section). These need extra iteration rounds.

**Cap iterations at 3-4 rounds.** If still not converging, the skill scope may be too broad -- consider splitting.

## Skill Types

Different skill types need different authoring and testing approaches.

### Technique
Concrete method with steps (condition-based-waiting, root-cause-tracing).
**Test with:** Application scenarios, edge case variations, missing information gaps.
**Success:** Agent applies technique correctly to new scenario.

### Pattern
Mental model for thinking about problems (flatten-with-flags, test-invariants).
**Test with:** Recognition scenarios, application scenarios, counter-examples.
**Success:** Agent correctly identifies when/how to apply pattern AND when NOT to.

### Reference
API docs, syntax guides, tool documentation.
**Test with:** Retrieval scenarios, application scenarios, gap testing.
**Success:** Agent finds and correctly applies reference information.

### Discipline-Enforcing
Rules and requirements (TDD, verification-before-completion).
**Test with:** Pressure scenarios (3+ combined pressures), rationalization capture.
**Success:** Agent follows rule under maximum pressure.

Discipline skills are the hardest to write. See "Bulletproofing" section below.

## Claude Search Optimization (CSO)

**Critical for discovery.** Future Claude reads the description to decide which skills to load.

### Description = When to Use, NOT What the Skill Does

**CRITICAL:** Testing revealed that when a description summarizes the skill's workflow, Claude follows the description as a shortcut instead of reading the full skill body. A description saying "code review between tasks" caused Claude to do ONE review, even though the skill's flowchart clearly showed TWO reviews.

When the description was changed to just triggering conditions (no workflow summary), Claude correctly read and followed the full skill.

```yaml
# BAD: Summarizes workflow - Claude may follow this instead of reading skill
description: Use when executing plans - dispatches subagent per task with code review between tasks

# BAD: Too much process detail
description: Use for TDD - write test first, watch it fail, write minimal code, refactor

# GOOD: Just triggering conditions, no workflow summary
description: Use when executing implementation plans with independent tasks in the current session

# GOOD: Triggering conditions only
description: Use when implementing any feature or bugfix, before writing implementation code
```

### Format Rules

- Start with "Use when..." to focus on triggering conditions
- Write in third person (injected into system prompt)
- Describe the *problem* not *language-specific symptoms* (race conditions, not setTimeout)
- Keep under 500 characters
- **NEVER summarize the skill's process or workflow**

### Keyword Coverage

Use words Claude would search for:
- Error messages: "Hook timed out", "ENOTEMPTY", "race condition"
- Symptoms: "flaky", "hanging", "zombie", "pollution"
- Synonyms: "timeout/hang/freeze", "cleanup/teardown/afterEach"
- Tools: Actual commands, library names, file types

### Naming

Use active voice, verb-first, gerunds work well:
- `creating-skills` not `skill-creation`
- `condition-based-waiting` not `async-test-helpers`
- `flatten-with-flags` not `data-structure-refactoring`

## Token Efficiency

Every token competes for context. Getting-started and frequently-referenced skills load into EVERY conversation.

**Target word counts:**
- Getting-started workflows: <150 words each
- Frequently-loaded skills: <200 words total
- Other skills: <500 words

**Techniques:**

Move details to tool help:
```markdown
# BAD: Document all flags in SKILL.md
search-conversations supports --text, --both, --after DATE, --before DATE, --limit N

# GOOD: Reference --help
search-conversations supports multiple modes and filters. Run --help for details.
```

Use cross-references instead of repeating:
```markdown
# BAD: Repeat workflow details from another skill
[20 lines of repeated instructions]

# GOOD: Reference other skill
Always use subagents. REQUIRED: Use [other-skill-name] for workflow.
```

Compress examples:
```markdown
# BAD: 42 words
your human partner: "How did we handle authentication errors in React Router before?"
You: I'll search past conversations for React Router authentication patterns.
[Dispatch subagent with search query: "React Router authentication error handling 401"]

# GOOD: 20 words
Partner: "How did we handle auth errors in React Router?"
You: Searching...
[Dispatch subagent -> synthesis]
```

**Verification:** `wc -w skills/path/SKILL.md`

## Code Examples

**One excellent example beats many mediocre ones.**

Choose most relevant language:
- Testing techniques: TypeScript/JavaScript
- System debugging: Shell/Python
- Data processing: Python

A good example is complete, runnable, well-commented (WHY not WHAT), from a real scenario, and ready to adapt.

Don't implement in 5+ languages, create fill-in-the-blank templates, or write contrived examples. Claude is good at porting -- one great example is enough.

## Bulletproofing Discipline Skills

Skills that enforce discipline need to resist rationalization. Agents are smart and will find loopholes under pressure.

**Psychology foundation:** See persuasion-principles.md for research (Cialdini, 2021; Meincke et al., 2025) on authority, commitment, scarcity, social proof, and unity.

### Close Every Loophole Explicitly

Don't just state the rule -- forbid specific workarounds:

```markdown
# BAD
Write code before test? Delete it.

# GOOD
Write code before test? Delete it. Start over.

**No exceptions:**
- Don't keep it as "reference"
- Don't "adapt" it while writing tests
- Don't look at it
- Delete means delete
```

### Address "Spirit vs Letter" Arguments

Add foundational principle early:

```markdown
**Violating the letter of the rules is violating the spirit of the rules.**
```

This cuts off the entire class of "I'm following the spirit" rationalizations.

### Build Rationalization Table

Capture rationalizations from baseline testing. Every excuse agents make goes in the table:

```markdown
| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "Keep as reference" | You'll adapt it. That's testing after. Delete means delete. |
```

### Create Red Flags List

Make it easy for agents to self-check:

```markdown
## Red Flags - STOP and Start Over
- Code before test
- "I already manually tested it"
- "Tests after achieve the same purpose"
- "It's about spirit not ritual"
- "This is different because..."
```

### Update Description for Violation Symptoms

Add symptoms of ABOUT to violate:

```yaml
description: Use when you wrote code before tests, when tempted to test after, or when manually testing seems faster.
```

## Testing Discipline Skills

For the full pressure-testing methodology, see testing-skills-with-subagents.md. Key principles:

### Pressure Types

| Pressure | Example |
|----------|---------|
| **Time** | Emergency, deadline, deploy window closing |
| **Sunk cost** | Hours of work, "waste" to delete |
| **Authority** | Senior says skip it, manager overrides |
| **Economic** | Job, promotion, company survival at stake |
| **Exhaustion** | End of day, already tired |
| **Social** | Looking dogmatic, seeming inflexible |
| **Pragmatic** | "Being pragmatic vs dogmatic" |

**Best tests combine 3+ pressures.**

### Meta-Testing

When an agent chooses wrong despite having the skill, ask:

> "You read the skill and chose Option C anyway. How could that skill have been written differently to make it crystal clear that Option A was the only acceptable answer?"

Three possible responses tell you what to fix:
1. **"Skill WAS clear, I chose to ignore it"** -- need stronger foundational principle
2. **"Skill should have said X"** -- documentation gap, add their suggestion
3. **"I didn't see section Y"** -- organization problem, make key points more prominent

## Flowcharts

Use ONLY for non-obvious decision points, process loops where you might stop too early, or "when to use A vs B" decisions.

Never for: reference material (tables), code examples (markdown blocks), linear instructions (numbered lists).

See graphviz-conventions.dot for style rules. Use `render-graphs.js` to render:
```bash
./render-graphs.js ../some-skill           # Each diagram separately
./render-graphs.js ../some-skill --combine # All diagrams in one SVG
```

## Anti-Patterns

- **Narrative storytelling**: "In session 2025-10-03, we found..." -- too specific, not reusable
- **Multi-language dilution**: example-js.js, example-py.py -- mediocre quality, maintenance burden
- **Code in flowcharts**: Can't copy-paste, hard to read
- **Generic labels**: helper1, step3 -- labels should have semantic meaning
- **Vague skill names**: `helper`, `utils`, `tools` -- name by what you DO

## Additional Resources

- testing-skills-with-subagents.md -- Full pressure-testing methodology with worked examples
- persuasion-principles.md -- Research on persuasion principles for skill design
- graphviz-conventions.dot -- Graphviz style rules for flowcharts
- examples/CLAUDE_MD_TESTING.md -- Complete worked example of a test campaign
