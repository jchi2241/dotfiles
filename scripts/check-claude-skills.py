#!/usr/bin/env python3
"""Check ~/.claude skills, commands, and CLAUDE.md for broken structure and references.

Exits 1 when any check fails. Run from anywhere:
    ~/.dotfiles/scripts/check-claude-skills.py
"""

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CLAUDE = REPO / ".claude"
SKILLS = CLAUDE / "skills"
COMMANDS = CLAUDE / "commands"
HOME = Path.home()
HELIOS = HOME / "projects" / "helios"

# Skills that live outside the dotfiles: Helios repo skills, Cursor built-ins, and plugins.
EXTERNAL_SKILL_ROOTS = [
    HELIOS / "agent" / "skills",
    HELIOS / ".cursor" / "skills",
    HOME / ".cursor" / "skills-cursor",
]
EXTERNAL_SKILL_GLOBS = [
    (HOME / ".cursor" / "plugins" / "cache", "**/skills/*/SKILL.md"),
    (HOME / ".claude" / "plugins" / "cache", "**/skills/*/SKILL.md"),
]
# Cursor built-in tools and skills referenced by name in prose.
BUILTIN_NAMES = {"create-skill", "create-rule", "loop"}
# Backticked `/name` tokens that are HTTP endpoints or mount paths, not slash commands.
NOT_COMMANDS = {"public", "alerts", "notes", "pg-data"}

errors: list[str] = []


def fail(path: Path, msg: str) -> None:
    errors.append(f"{path.relative_to(REPO)}: {msg}")


def frontmatter(text: str) -> dict[str, str] | None:
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return None
    fields: dict[str, str] = {}
    key = None
    for line in m.group(1).splitlines():
        kv = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if kv:
            key = kv.group(1)
            fields[key] = kv.group(2).strip()
        elif key and line.startswith((" ", "\t")):
            fields[key] = (fields[key] + " " + line.strip()).strip()
    return fields


def known_skill_names() -> set[str]:
    names = {p.name for p in SKILLS.iterdir() if (p / "SKILL.md").is_file()}
    for root in EXTERNAL_SKILL_ROOTS:
        if root.is_dir():
            names |= {p.name for p in root.iterdir() if (p / "SKILL.md").is_file()}
    for root, pattern in EXTERNAL_SKILL_GLOBS:
        if root.is_dir():
            names |= {p.parent.name for p in root.glob(pattern)}
    return names | BUILTIN_NAMES


def check_skill_dirs() -> None:
    for d in sorted(p for p in SKILLS.iterdir() if p.is_dir()):
        skill = d / "SKILL.md"
        if not skill.is_file():
            fail(d, "skill directory has no SKILL.md")
            continue
        fm = frontmatter(skill.read_text())
        if fm is None:
            fail(skill, "missing YAML frontmatter")
            continue
        if fm.get("name") != d.name:
            fail(skill, f"frontmatter name {fm.get('name')!r} does not match directory {d.name!r}")
        if not fm.get("description"):
            fail(skill, "frontmatter description is empty")
        if d.name.startswith("principle-") and fm.get("disable-model-invocation") != "true":
            fail(skill, "principle skills must set disable-model-invocation: true")


def check_principles_index() -> None:
    claude_md = CLAUDE / "CLAUDE.md"
    text = claude_md.read_text()
    for d in sorted(SKILLS.glob("principle-*")):
        if f"~/.claude/skills/{d.name}/SKILL.md" not in text:
            fail(claude_md, f"principles index has no row for {d.name}")


def check_router() -> None:
    router = SKILLS / "chi-mode" / "SKILL.md"
    if not router.is_file():
        return
    text = router.read_text()
    for pb in sorted((SKILLS / "chi-mode" / "playbooks").glob("*.md")):
        if f"playbooks/{pb.name}" not in text:
            fail(router, f"router has no row for playbooks/{pb.name}")


# Model names belong only in the CLAUDE.md models table. These skills cite model names as query data.
MODEL_DATA_SKILLS = {"debugging-umg-incidents", "querying-grafana"}
MODEL_NAME = re.compile(
    r"\b(?:claude-(?:opus|sonnet|haiku)-\d[\w.-]*|gpt-\d[\w.-]*|(?:cursor-)?grok-\d[\w.-]*|composer-\d[\w.-]*)"
    r"|model: \*\*(?:opus|sonnet|haiku)\*\*"
)


def model_roles() -> set[str]:
    claude_md = CLAUDE / "CLAUDE.md"
    m = re.search(r"<!-- models:begin -->(.*?)<!-- models:end -->", claude_md.read_text(), re.S)
    if not m:
        fail(claude_md, "missing <!-- models:begin --> ... <!-- models:end --> table")
        return set()
    return set(re.findall(r"^\| `([^`]+)` \|", m.group(1), re.M))


def check_models(files: list[Path], roles: set[str]) -> None:
    used: set[str] = set()
    for f in files:
        text = f.read_text()
        for role in re.findall(r"model role `([^`<]+)`", text):
            used.add(role)
            if role not in roles:
                fail(f, f"unknown model role: {role}")
        if f.name == "CLAUDE.md" or MODEL_DATA_SKILLS & set(f.parts):
            continue
        for name in sorted(set(MODEL_NAME.findall(text))):
            fail(f, f"names a model directly ({name}); use a model role from ~/.claude/CLAUDE.md")
    for role in sorted(roles - used):
        fail(CLAUDE / "CLAUDE.md", f"model role {role!r} is not referenced by any skill or command")


def doc_files() -> list[Path]:
    files = [CLAUDE / "CLAUDE.md", CLAUDE / "VOICE.md"]
    files += sorted(COMMANDS.glob("*.md"))
    files += sorted(SKILLS.rglob("*.md"))
    return [f for f in files if f.is_file()]


def strip_code_blocks(text: str) -> str:
    return re.sub(r"```.*?```", "", text, flags=re.S)


PLACEHOLDER = re.compile(r"[<>*{}$]|YYYY|\.\.\.")


def check_references(files: list[Path], skills: set[str]) -> None:
    commands = {p.stem for p in COMMANDS.glob("*.md")}
    for f in files:
        text = strip_code_blocks(f.read_text())

        for target in re.findall(r"\]\(([^)\s]+)\)", text):
            if re.match(r"^[a-z]+:", target) or target.startswith("#"):
                continue
            path = target.split("#")[0]
            if not re.search(r"[./]", path) or PLACEHOLDER.search(path):
                continue
            if not (f.parent / path).exists():
                fail(f, f"broken link: {target}")

        for raw in re.findall(r"~/\.claude/[A-Za-z0-9_./-]+", text):
            path = raw.rstrip(".,:;")
            if PLACEHOLDER.search(path) or path.endswith("-"):
                continue
            if not (HOME / path[2:]).exists():
                fail(f, f"missing path: {path}")

        for rel in re.findall(r"Helios `((?:agent|agents|migrations)/[A-Za-z0-9_./-]+)`", text):
            if HELIOS.is_dir() and not (HELIOS / rel).exists():
                fail(f, f"missing Helios path: {rel}")

        # Skill names: "the `x` skill", "`x` skill", "`x`'s", and any `principle-*`.
        named = set(re.findall(r"`([a-z0-9][a-z0-9-]*)`(?:\s+skill|'s)", text))
        named |= set(re.findall(r"`(principle-[a-z0-9-]+)`", text))
        for name in sorted(named - skills):
            fail(f, f"unknown skill: {name}")

        for name in sorted(set(re.findall(r"`/([a-z][a-z0-9-]+)(?=[` ])", text))):
            if not (name in commands or name in skills or name in NOT_COMMANDS or Path("/", name).exists()):
                fail(f, f"unknown command: /{name}")


def main() -> int:
    check_skill_dirs()
    check_principles_index()
    check_router()
    check_references(doc_files(), known_skill_names())
    check_models(doc_files(), model_roles())
    if errors:
        print("\n".join(errors))
        print(f"\n{len(errors)} problem(s) in ~/.claude skills.", file=sys.stderr)
        return 1
    print("~/.claude skills: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
