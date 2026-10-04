# `use heavy_slots` in an .envrc (or .envrc.private) puts the heavy-slots
# shims first on PATH, so go/pnpm/npm/npx builds, tests, and lints queue
# for a machine-wide slot. See ~/.dotfiles/bin/heavy-slots.
use_heavy_slots() {
	PATH_add "$HOME/.local/libexec/heavy-shims"
}
