---
name: pr-image-upload
description: Use when uploading local screenshots, images, GIFs, or visual artifacts to a GitHub PR or issue body, especially review-ready PR workflows, "attach this screenshot", "add the image from ~/Pictures", "use gh-image", "user-attachments", or "add visual proof without repo clutter".
allowed-tools: Bash(gh extension:*), Bash(gh image:*), Bash(gh pr view:*), Bash(gh pr edit:*), Bash(python3:*), Bash(ls:*), Bash(pwd:*), Read, Glob
---

# PR Image Upload

Use `gh-image` to upload local images to GitHub `user-attachments` storage and insert the returned Markdown into a PR or issue body. Prefer this for review-ready PRs that need visual proof without release assets, asset branches, or committed screenshots.

## Workflow

### 1. Find and inspect the image

If the user gives an exact path, use it. If they say `~/Pictures` or similar, use `Glob` for `*.png`, `*.jpg`, `*.jpeg`, `*.webp`, and `*.gif`. If multiple files match and none is obviously the intended recent screenshot, ask.

For screenshots generated during a review-ready PR workflow, expect them in `~/Pictures` with descriptive names. Do not look in `/tmp` first unless the user points there or the artifact was created before this convention.

Before uploading, read the image with the image-capable read tool when available. Confirm it is the expected visual artifact and not private or accidental.

### 2. Install or verify `gh-image`

```bash
gh extension list
```

If missing:

```bash
gh extension install drogers0/gh-image
```

Use `drogers0/gh-image`; `p-nerd/gh-image` may not exist.

### 3. Upload the image

```bash
gh image "/absolute/path/to/screenshot.png"
```

Do not use `gh image upload <file>`; this extension's syntax is `gh image <image-path>...`. The output should be Markdown:

```markdown
![name.png](https://github.com/user-attachments/assets/...)
```

If the command prints a warning but also returns a valid `user-attachments` URL, the upload likely succeeded.

### 4. Update the PR body safely

Avoid Bash parameter replacement for `[INSERT VIDEO]`; square brackets are pattern characters and can corrupt the body. Use Python for literal replacement:

```bash
IMG_MD='![name.png](https://github.com/user-attachments/assets/...)'
BODY=$(gh pr view 123 --json body --jq .body)
UPDATED_BODY=$(BODY="$BODY" IMG_MD="$IMG_MD" python3 - <<'PY'
import os

body = os.environ["BODY"]
img = os.environ["IMG_MD"]
placeholder = "[INSERT VIDEO]"

if placeholder in body:
    print(body.replace(placeholder, img))
else:
    print(body.rstrip() + "\n\n" + img)
PY
)
gh pr edit 123 --body "$UPDATED_BODY"
```

If the PR has a stale placeholder like `[INSERT VIDEO]`, replace it with the real artifact. Phrase the test plan honestly: say screenshot when the artifact is a screenshot.

### 5. Verify

```bash
gh pr view 123 --json body --jq .body
```

Check that:

- The body is not mangled.
- The attachment appears exactly once.
- The URL is `https://github.com/user-attachments/assets/...`.
- No release asset, raw branch URL, or committed file path was used.

## Safety notes

- Do not commit screenshots or other binary proof artifacts to the product branch unless the user explicitly requests it.
- Do not create GitHub releases or tags for PR images unless the user explicitly asks for the release-asset workaround.
- Do not use `--token` on a shared machine unless needed; command-line token values can appear in process listings. Prefer existing `gh` auth or `GH_SESSION_TOKEN` if a session token is required.
- If upload fails because the extension cannot extract a browser session token, explain that manual drag-and-drop in the GitHub UI is the clean fallback.
