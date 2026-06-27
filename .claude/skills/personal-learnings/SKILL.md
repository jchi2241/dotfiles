---
name: personal-learnings
description: Use when reading, creating, or updating personal technical learnings, hardware troubleshooting, or system configuration guides in the dotfiles repository.
---

# Personal Learnings Management

This skill outlines the conventions for indexing, reading, and writing personal technical learnings, hardware troubleshooting, and system configuration guides inside the `~/.dotfiles/docs/` directory.

---

## 1. Directory Structure

All personal learnings must be stored under the `docs/` directory at the root of the dotfiles repository, categorized by topic:

```text
~/.dotfiles/docs/
├── troubleshooting/  # OS, hardware, and peripheral issue resolutions
├── configuration/    # Custom system, desktop, or app configurations
└── workflows/        # Personal development workflows and cheat sheets
```

---

## 2. File Naming Convention (Self-Documenting & Chronological)

To prevent context bloat and eliminate the need for a central index file, filenames must be completely self-documenting and prefixed with the date. 

### Format:
`docs/<category>/YYYY-MM-DD_<problem>-on-<context>-<solution-keywords>.md`

### Examples:
*   `docs/troubleshooting/2026-06-27_dropped-keystrokes-mouse-lag-on-4k-120hz-hdmi-emi-fix-usb-autosuspend.md`
*   `docs/configuration/2026-05-12_wayland-wl-copy-setup-on-ubuntu-24-04.md`

---

## 3. Mandatory Frontmatter (Context Engineering)

To allow LLMs and agents to quickly evaluate if a document is relevant to a user query *without* reading the entire file, **every document must contain a standardized YAML frontmatter block at the very top.**

### Standard Frontmatter Schema:
```yaml
---
title: <Human readable title of the learning>
summary: <1-2 sentence high-level summary of the issue and the solution>
symptoms: <Brief bulleted list of observable symptoms>
root_cause: <Brief explanation of the underlying technical cause>
fix: <Brief summary of the concrete resolution steps>
tags: [<list, of, search, tags>]
date: YYYY-MM-DD
---
```

---

## 4. Workflow for Agents

### A. When Reading / Searching Learnings:
1.  **Do not read full files blindly.**
2.  Run a `Glob` search in `docs/` first (e.g., `docs/**/*.md`).
3.  Examine the filenames. Because they are self-documenting, you should be able to identify 1 or 2 candidate files.
4.  If multiple files look similar, read **only the first 10 lines** of those files to inspect the YAML frontmatter.
5.  Once the correct file is identified via its frontmatter, read the full file to extract the solution.

### B. When Creating a New Learning:
1.  Confirm with the user that they want to document the learning.
2.  Formulate a descriptive, date-prefixed, kebab-case filename.
3.  Write the file with the **Mandatory Frontmatter** block at the top.
4.  Keep the body of the document highly structured (Symptoms, Root Cause, Solutions/Commands).
5.  Offer to commit and sync the changes using the `/dotfiles-sync` command.
