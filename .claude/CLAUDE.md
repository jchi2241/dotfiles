# CLAUDE.md

## System & Environment
- jchi uses Linux (Ubuntu 24.04 LTS Noble) as their laptop OS. Tailor installation instructions and system-specific answers to Linux accordingly.
- For clipboard operations, use `wl-copy` (Wayland) instead of `xclip` or `xsel`.
- User's name is Justin Chi. When searching git commits, use author filters like: --author="jchi" or --author="Justin Chi" (email: jchi@memsql.com)
- When asked to fix Claude settings, commands, or skills, look in `~/.claude/` rather than `.claude/`.

## General Guidelines
- **Evidence-Based Reasoning:** Findings and reasonings must be grounded on concrete evidence from search, grep, tests, and tools.
- **Technical Excellence:** When making technical decisions, do not give much weight to development cost. Instead, prefer quality, simplicity, robustness, scalability, and long-term maintainability.
- **E2E Bug Reproduction:** When doing bug fixes, always start by reproducing the bug in an E2E setting as closely aligned with how an end user would experience it as possible. This ensures you find the real problem so your fix actually solves it.
- **UI & Pixel Perfection:** When end-to-end testing a product, be picky about the UI you see and be obsessed with pixel perfection.
- **One Sentence Per Line:** When writing or substantially editing long Markdown files, put each full sentence on its own line.
