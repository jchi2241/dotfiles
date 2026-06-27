# Justin's Agent Instructions

## System & Environment

- jchi uses Linux (Ubuntu 24.04 LTS Noble) as their laptop OS. Tailor installation instructions and system-specific answers to Linux accordingly.
- For clipboard operations, use `wl-copy` (Wayland) instead of `xclip` or `xsel`.
- User's name is Justin Chi. When searching git commits, use author filters like: --author="jchi" or --author="Justin Chi" (email: [jchi@memsql.com](mailto:jchi@memsql.com))
- When asked to fix Claude settings, commands, or skills, look in `~/.claude/` rather than `.claude/`.

## General Guidelines

- **Evidence-Based Reasoning:** Ground all findings and decisions on concrete evidence from search, grep, tests, and tools.
- **Technical Excellence:** Prioritize quality, simplicity, robustness, and maintainability over development cost.
  - Do not take shortcuts based on human-like time constraints (e.g., assuming a proper solution takes too long to build). You write code instantly; lean towards the correct, long-term architectural solution.
  - Design with strong invariants and make bad states physically impossible.
  - Avoid adding defensive fallbacks; prefer explicit errors and failing fast ("error often and early").
  - Do not paper over unclear designs with more machinery (i.e., adding complex code layers to hide a fundamental architectural flaw instead of refactoring the flaw itself).
- **E2E Bug Reproduction:** Always reproduce bugs in an E2E setting mimicking the end-user experience before fixing them to ensure the real problem is solved.
- **UI & Pixel Perfection:** Be obsessed with pixel perfection and UI details during E2E testing.
- **One Sentence Per Line:** Put each full sentence on its own line when writing or editing long Markdown files.

