---
name: notebook-tools
description: Use when searching, diffing, or inspecting Jupyter notebooks (.ipynb files). Trigger when grepping notebook code, reviewing notebook PRs, comparing notebook versions across commits, or listing/reading notebook cells.
---

# Notebook Tools

Jupyter notebooks are JSON — standard grep/diff/cat produce unusable noise. Use these recipes instead.

## Prerequisites

- `jq` (for grep/inspect — pipe-friendly)
- `nbdime` (for diffing — registered as git diff driver via `nbdime config-git --enable`)

## Grepping Notebook Code

Search cell sources for a pattern. Returns cell index, type, and matching lines.

```bash
# Grep all cells for a pattern (with cell headers + line numbers)
jq -r '.cells | to_entries[] | "=== Cell \(.key) (\(.value.cell_type)) ===\n" + (.value.source | join(""))' FILE.ipynb \
  | grep -n "PATTERN"

# Grep a notebook at a specific git commit
git show COMMIT:path/to/notebook.ipynb \
  | jq -r '.cells | to_entries[] | "=== Cell \(.key) (\(.value.cell_type)) ===\n" + (.value.source | join(""))' \
  | grep -n "PATTERN"

# Case-insensitive, with context lines
jq -r '.cells | to_entries[] | "=== Cell \(.key) (\(.value.cell_type)) ===\n" + (.value.source | join(""))' FILE.ipynb \
  | grep -ni -C3 "PATTERN"
```

## Listing Cells (Table of Contents)

Get a quick overview of notebook structure — cell index, type, and first line.

```bash
# List all cells with first-line summary
jq -r '.cells | to_entries[] | "\(.key)\t\(.value.cell_type)\t\(.value.source[0] // "(empty)" | ltrimstr(" ") | ltrimstr("\n"))"' FILE.ipynb

# Same, for a specific commit
git show COMMIT:path/to/notebook.ipynb \
  | jq -r '.cells | to_entries[] | "\(.key)\t\(.value.cell_type)\t\(.value.source[0] // "(empty)" | ltrimstr(" ") | ltrimstr("\n"))"'

# Count cells
jq '.cells | length' FILE.ipynb
```

## Reading a Specific Cell

Extract the full source of one cell by index.

```bash
# Read cell N (zero-indexed)
jq -r --argjson n CELL_INDEX '.cells[$n].source | join("")' FILE.ipynb

# Read cell N at a specific commit
git show COMMIT:path/to/notebook.ipynb \
  | jq -r --argjson n CELL_INDEX '.cells[$n].source | join("")'

# Read a range of cells (e.g., cells 19-22)
jq -r '.cells[19:23] | to_entries[] | "=== Cell \(.key + 19) ===\n" + (.value.source | join(""))' FILE.ipynb
```

## Diffing Notebooks

nbdime is registered as the git diff driver, so `git diff` just works for `.ipynb` files:

```bash
# Diff working copy against last commit
git diff -- path/to/notebook.ipynb

# Diff between two commits
git diff COMMIT_A COMMIT_B -- path/to/notebook.ipynb

# Browser-based rich diff (if display available)
git show COMMIT_A:path/to/notebook.ipynb > /tmp/nb_old.ipynb
git show COMMIT_B:path/to/notebook.ipynb > /tmp/nb_new.ipynb
nbdiff-web /tmp/nb_old.ipynb /tmp/nb_new.ipynb
```

For **source-only diff** (strips JSON noise, no nbdime needed):

```bash
git show COMMIT_A:path/to/notebook.ipynb \
  | jq -r '.cells | to_entries[] | "=== Cell \(.key) (\(.value.cell_type)) ===\n" + (.value.source | join(""))' \
  > /tmp/nb_before.txt
git show COMMIT_B:path/to/notebook.ipynb \
  | jq -r '.cells | to_entries[] | "=== Cell \(.key) (\(.value.cell_type)) ===\n" + (.value.source | join(""))' \
  > /tmp/nb_after.txt
diff -u /tmp/nb_before.txt /tmp/nb_after.txt
```

Note: the jq source-only diff has a limitation — if cells are inserted/deleted, all subsequent cells appear "changed" due to index shift. Use `git diff` (with nbdime) for structural diffs, or the Python cell-matcher below.

## Smart Cell Matching (Handles Insertions/Deletions)

When cells are inserted or deleted, index-based diffs break. Use content hashing to match cells by content instead:

```bash
python3 -c "
import json, sys, hashlib

def cell_hash(cell):
    src = ''.join(cell.get('source', []))
    return hashlib.md5(src.encode()).hexdigest()[:12]

def load_cells(data):
    nb = json.loads(data)
    return [(i, cell_hash(c), ''.join(c.get('source',[]))) for i, c in enumerate(nb['cells'])]

import subprocess
old = subprocess.run(['git', 'show', 'COMMIT_A:PATH'], capture_output=True, text=True).stdout
new = subprocess.run(['git', 'show', 'COMMIT_B:PATH'], capture_output=True, text=True).stdout

old_cells = load_cells(old)
new_cells = load_cells(new)

old_hashes = {h: (i, src) for i, h, src in old_cells}
new_hashes = {h: (i, src) for i, h, src in new_cells}

added = [h for h in new_hashes if h not in old_hashes]
removed = [h for h in old_hashes if h not in new_hashes]
moved = [(old_hashes[h][0], new_hashes[h][0]) for h in old_hashes if h in new_hashes and old_hashes[h][0] != new_hashes[h][0]]

print(f'Cells: {len(old_cells)} -> {len(new_cells)}')
print(f'Added ({len(added)}):')
for h in added:
    i, src = new_hashes[h]
    print(f'  [{i}] {src[:80]}...')
print(f'Removed ({len(removed)}):')
for h in removed:
    i, src = old_hashes[h]
    print(f'  [{i}] {src[:80]}...')
print(f'Moved ({len(moved)}):')
for old_i, new_i in moved[:10]:
    print(f'  [{old_i}] -> [{new_i}]')
"
```

Replace `COMMIT_A`, `COMMIT_B`, and `PATH` with actual values.

## Searching for Specific Constructs

```bash
# Find cells with specific imports
jq -r '.cells | to_entries[] | select(.value.source | join("") | test("^(import |from ).*MODULE_NAME"; "m")) | "Cell \(.key): \(.value.source[0])"' FILE.ipynb

# Find function definitions
jq -r '.cells | to_entries[] | select(.value.source | join("") | test("def FUNC_NAME"; "m")) | "Cell \(.key)"' FILE.ipynb

# Find class definitions
jq -r '.cells | to_entries[] | select(.value.source | join("") | test("class CLASS_NAME"; "m")) | "Cell \(.key)"' FILE.ipynb

# Find cells with specific variable assignments
jq -r '.cells | to_entries[] | select(.value.source | join("") | test("^VARNAME\\s*="; "m")) | "Cell \(.key)"' FILE.ipynb
```

## When Reviewing Notebook PRs

For large notebook diffs (hundreds+ lines), use subagents to protect main context:

1. **Structure overview**: List cells before/after to identify insertions/deletions
2. **Smart cell match**: Use the content-hash matcher to find actually-changed cells
3. **Targeted reads**: Read only the changed cells, not the entire notebook
4. **git diff with nbdime**: Use `git diff COMMIT_A COMMIT_B -- path` for the structural view

Avoid reading the raw JSON diff — it will flood context with noise.
