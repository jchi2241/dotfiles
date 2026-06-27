# Justin's Agent Instructions

## System & Environment

- jchi uses Linux (Ubuntu 24.04 LTS Noble) as their laptop OS. Tailor installation instructions and system-specific answers to Linux accordingly.
- For clipboard operations, use `wl-copy` (Wayland) instead of `xclip` or `xsel`.
- User's name is Justin Chi. When searching git commits, use author filters like: --author="jchi" or --author="Justin Chi" (email: [jchi@memsql.com](mailto:jchi@memsql.com))
- When asked to fix Claude settings, commands, or skills, look in `~/.claude/` rather than `.claude/`.

## General Guidelines

- **Evidence-Based Reasoning:** Ground all findings and decisions on concrete evidence from search, grep, tests, and tools.
- **No Shortcuts (Instant Execution):** Prioritize quality, simplicity, robustness, and maintainability over development cost. Do not take shortcuts based on human-like time constraints (e.g., assuming a proper solution takes too long to build). You write code instantly; always choose the correct, long-term architectural solution.
- **Design with strong invariants:** Do not write code to "handle" invalid data if that data shouldn't exist in the first place. Use the type system, schemas, and strict invariants to make bad states impossible to represent. 
- **Error often and early:** Prefer explicit errors and failing fast.
- **Refactor over Accumulation:** Do not paper over unclear designs with more machinery (i.e., appending new conditionals, wrappers, or fallbacks to hide a fundamental architectural flaw). Refactor the underlying flaw itself.
- **Human Comprehensibility (Anti-Slop):** Write code optimized for human legibility and comprehension. A human must be able to easily comprehend and explain your code without needing an LLM to translate it first.
- **E2E Bug Reproduction:** Always reproduce bugs in an E2E setting mimicking the end-user experience before fixing them to ensure the real problem is solved.
- **One Sentence Per Line:** Put each full sentence on its own line when writing or editing long Markdown files.

