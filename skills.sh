#!/usr/bin/env bash
#
# Install/update agent skills listed in skills.txt using the `skills` npx CLI
# (https://github.com/vercel-labs/skills).
#
# Usage:
#   ./skills.sh            # install every source in skills.txt
#   ./skills.sh update     # update already-installed skills to latest
#
# Config (env vars):
#   SKILLS_MANIFEST   Path to the manifest   (default: ./skills.txt)
#   SKILLS_AGENTS     Space-separated agents (default: cursor)
#   SKILLS_SCOPE      global | project       (default: global -> ~/.cursor/skills)
#
# Requires Node >= 22.20.0 (the skills CLI's minimum) and network access.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${SKILLS_MANIFEST:-$DOTFILES_DIR/skills.txt}"
AGENTS="${SKILLS_AGENTS:-cursor}"
SCOPE="${SKILLS_SCOPE:-global}"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

require_node() {
  have node || err "node not found. Install Node >= 22.20.0 to use the skills CLI."
  have npx  || err "npx not found. Install Node >= 22.20.0 (npm) to use the skills CLI."
  local v major minor rest
  v="$(node -v)"; v="${v#v}"
  major="${v%%.*}"; rest="${v#*.}"; minor="${rest%%.*}"
  if [ "$major" -lt 22 ] || { [ "$major" -eq 22 ] && [ "$minor" -lt 20 ]; }; then
    err "Node $v found, but the skills CLI needs >= 22.20.0. Upgrade Node (e.g. via nvm/fnm/volta) and retry."
  fi
}

# Build the shared agent/scope flag arrays.
agent_flags=()
for a in $AGENTS; do agent_flags+=(-a "$a"); done

scope_flag=()
if [ "$SCOPE" = "global" ]; then
  scope_flag=(-g)
elif [ "$SCOPE" != "project" ]; then
  err "SKILLS_SCOPE must be 'global' or 'project' (got '$SCOPE')."
fi

do_update() {
  info "Updating installed skills (scope: $SCOPE)..."
  npx --yes skills@latest update "${scope_flag[@]}" -y
  info "Done."
}

do_install() {
  [ -f "$MANIFEST" ] || err "Manifest not found: $MANIFEST"
  info "Installing skills from $MANIFEST (agents: $AGENTS, scope: $SCOPE)..."

  local count=0 line source parts skills skill_flags s
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"                 # strip inline comments
    [ -z "${line//[[:space:]]/}" ] && continue  # skip blank/whitespace-only

    read -ra parts <<< "$line"
    source="${parts[0]}"
    skills=("${parts[@]:1}")
    [ "${#skills[@]}" -eq 0 ] && skills=('*')   # default: all skills

    skill_flags=()
    for s in "${skills[@]}"; do skill_flags+=(-s "$s"); done

    info "add $source  (skills: ${skills[*]})"
    npx --yes skills@latest add "$source" "${agent_flags[@]}" "${scope_flag[@]}" "${skill_flags[@]}" -y
    count=$((count + 1))
  done < "$MANIFEST"

  info "Done. Installed from $count source(s)."
}

main() {
  require_node
  case "${1:-install}" in
    install) do_install ;;
    update)  do_update ;;
    *) err "Unknown command '$1'. Use: install | update" ;;
  esac
}

main "$@"
