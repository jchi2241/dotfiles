---
name: pr-image-upload
description: Use when uploading local screenshots, images, GIFs, or visual artifacts to a GitHub PR or issue body, especially review-ready PR workflows, "attach this screenshot", "add the image from ~/Pictures", "gh pr edit --attach", "user-attachments", or "add visual proof without repo clutter".
allowed-tools: Bash(gh pr view:*), Bash(gh pr edit:*), Bash(gh issue view:*), Bash(gh issue edit:*), Bash(gh --version:*), Bash(python3:*), Bash(ls:*), Bash(pwd:*), Read, Glob
---

# PR Image Upload

Upload local images into GitHub `user-attachments` and put them in a PR or issue body. Do not commit binaries, create releases, or mint asset-branch URLs unless the user asks.

Use native `gh --attach` (gh 2.99+). It uses existing `gh` API auth.

## Workflow

### 1. Find and inspect the image

Use the path the user gave. For `~/Pictures`, Glob `*.png`, `*.jpg`, `*.jpeg`, `*.webp`, `*.gif`. Ask if several files could match.

For review-ready PR screenshots, expect `~/Pictures` with descriptive names. Skip `/tmp` unless the user points there or this conversation already wrote the file.

Read the image when available. Confirm it is the expected visual, not private or accidental. Do not crop-and-upscale screenshots before upload. Attach native pixels; if the subject is too small, recapture rather than inventing resolution.

### 2. Confirm native `--attach`

```bash
gh pr edit --help
```

If `--attach` is listed, use it. In Helios, run `gh` through `direnv exec .` so the Nix-pinned CLI (2.99+) is used instead of an older system `gh`. If `--attach` is missing, ask the user to drag-and-drop in the GitHub UI.

### 3. Attach with local markdown refs

`--attach` uploads the file and rewrites matching local image refs in the body to `https://github.com/user-attachments/assets/...`. Put the refs in the body first, then attach using the **same path string** as in the markdown.

Rewrite matches the markdown target to the `--attach` argument, not the filename. `./foo.png` in the body plus `--attach /tmp/shots/foo.png` does **not** rewrite: the files still upload, and `gh` **appends** a second image block at the bottom (alt text = filename). Use one of:

```markdown
![External Trial organization sees the Standard subscription required alert](./analyst-install-external-trial.png)
```

```bash
# cwd contains the images, same relative path as the markdown
gh pr edit 123 --body-file ./body.md \
  --attach ./analyst-install-external-trial.png \
  --attach './login.png#The login error state'
```

or keep the images elsewhere and use that exact path in both places:

```markdown
![...](/tmp/analyst-shots/analyst-install-external-trial.png)
```

```bash
gh pr edit 123 --body-file ./body.md \
  --attach /tmp/analyst-shots/analyst-install-external-trial.png
```

`--attach '<file>#<alt text>'` sets alt text on appended images; otherwise the filename is used. Without `--body` / `--body-file`, the existing body is kept and attachments are appended. Use `--body-file` to place images in a specific section. Max 50 files per command.

For issues: `gh issue edit <n> --attach ...` with the same pattern.

If some attachments fail, the body may still include the successful ones. Re-run only the failed files.

### 4. Verify

```bash
gh pr view 123 --json body --jq .body
```

Body not mangled; each image **once**; URLs are `https://github.com/user-attachments/assets/...`; no leftover `./file.png` or absolute local paths; no release, branch, or committed-file URLs.

If you see both local refs **and** extra `![filename](https://github.com/user-attachments/assets/...)` lines at the bottom, rewrite failed. Splice the uploaded URLs into the intended captions, drop the appended copies, and `gh pr edit --body-file` the corrected body (no second `--attach`).

Say screenshot when it is a screenshot. Replace stale `[INSERT VIDEO]` placeholders.

## Safety notes

Do not commit screenshots or create releases unless the user asks. `--attach` arguments are file paths, not secrets.
