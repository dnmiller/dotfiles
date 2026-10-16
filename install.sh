#!/usr/bin/env bash
#
# Dotfiles installer.
#
# Usage:
#   git clone <this-repo> ~/.dotfiles && ~/.dotfiles/install.sh
#
# Idempotent: safe to re-run. It installs oh-my-zsh and Powerlevel10k if
# missing, then symlinks everything under home/ into $HOME, backing up any
# existing real files first.

set -euo pipefail

# Resolve the directory this script lives in (so it works from anywhere).
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_SRC="$DOTFILES_DIR/home"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

ZSH_DIR="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH_DIR/custom}"

# nvm release to bootstrap, and the Node minimum required by the skills CLI.
NVM_VERSION="${NVM_VERSION:-v0.40.8}"
NODE_MIN_MAJOR=22
NODE_MIN_MINOR=20

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

# True if a node is on PATH that satisfies NODE_MIN_MAJOR.NODE_MIN_MINOR.
node_ok() {
  have node || return 1
  local v major minor rest
  v="$(node -v)"; v="${v#v}"
  major="${v%%.*}"; rest="${v#*.}"; minor="${rest%%.*}"
  [ "$major" -gt "$NODE_MIN_MAJOR" ] && return 0
  [ "$major" -eq "$NODE_MIN_MAJOR" ] && [ "$minor" -ge "$NODE_MIN_MINOR" ]
}

# --- oh-my-zsh ---------------------------------------------------------------
install_oh_my_zsh() {
  if [ -d "$ZSH_DIR" ]; then
    info "oh-my-zsh already installed."
    return
  fi
  info "Installing oh-my-zsh..."
  # RUNZSH/CHSH=no keep the installer non-interactive and leave our .zshrc alone.
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
}

# --- Powerlevel10k -----------------------------------------------------------
install_p10k() {
  local dest="$ZSH_CUSTOM/themes/powerlevel10k"
  if [ -d "$dest" ]; then
    info "Powerlevel10k already installed."
    return
  fi
  info "Installing Powerlevel10k..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$dest"
}

# --- Symlink dotfiles --------------------------------------------------------
link_file() {
  local src="$1" dest="$2"

  # Already the correct symlink? Nothing to do.
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    info "ok    $dest"
    return
  fi

  # Back up anything already there (real file or wrong symlink).
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    mkdir -p "$BACKUP_DIR"
    warn "backup $dest -> $BACKUP_DIR/"
    mv "$dest" "$BACKUP_DIR/"
  fi

  ln -s "$src" "$dest"
  info "link  $dest -> $src"
}

link_dotfiles() {
  info "Symlinking dotfiles into $HOME..."
  # Top-level entries in home/ (dotfiles and regular), excluding . and ..
  local entry name
  shopt -s dotglob nullglob
  for entry in "$HOME_SRC"/*; do
    name="$(basename "$entry")"
    link_file "$entry" "$HOME/$name"
  done
  shopt -u dotglob nullglob
}

# --- Node (via nvm) ----------------------------------------------------------
install_nvm() {
  if [ "${SKIP_NVM:-}" = "1" ] || [ "${SKIP_SKILLS:-}" = "1" ]; then
    info "Skipping Node/nvm bootstrap."
    return
  fi
  if node_ok; then
    info "Node $(node -v) already satisfies >= $NODE_MIN_MAJOR.$NODE_MIN_MINOR."
    return
  fi

  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    info "Installing nvm $NVM_VERSION..."
    # PROFILE=/dev/null: don't let the installer edit shell rc files; our
    # version-controlled .zshrc already sources nvm.
    PROFILE=/dev/null \
      bash -c "$(curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh")"
  else
    info "nvm already installed."
  fi

  # Load nvm into this script so `node`/`npx` are usable below.
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"

  info "Installing latest Node LTS via nvm..."
  nvm install --lts
  nvm alias default 'lts/*' >/dev/null
  nvm use default >/dev/null

  if node_ok; then
    info "Using Node $(node -v)."
  else
    warn "Installed Node $(node -v || echo '?') does not meet >= $NODE_MIN_MAJOR.$NODE_MIN_MINOR."
  fi
}

# --- CLI tools (Nix) ---------------------------------------------------------
# Builds the package set in flake.nix to a fixed out-link (also a GC root)
# whose bin/ is on PATH via .zshrc. Never touches the user's Nix profile, so it
# works with nix-env or `nix profile` setups alike.
TOOLS_LINK="$HOME/.local/state/dotfiles/tools"

find_nix() {
  have nix && return 0
  local f
  for f in "$HOME/.nix-profile/etc/profile.d/nix.sh" \
           /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
           /nix/var/nix/profiles/default/etc/profile.d/nix.sh; do
    # shellcheck disable=SC1090
    [ -e "$f" ] && . "$f" && have nix && return 0
  done
  return 1
}

install_tools() {
  if [ "${SKIP_TOOLS:-}" = "1" ]; then
    info "SKIP_TOOLS=1 set; skipping CLI tools."
    return
  fi
  if ! find_nix; then
    warn "nix not found; skipping CLI tools (neovim etc.)."
    return
  fi
  info "Building CLI tools from flake.nix..."
  mkdir -p "$(dirname "$TOOLS_LINK")"
  if nix --extra-experimental-features 'nix-command flakes' \
      build "$DOTFILES_DIR#default" --out-link "$TOOLS_LINK"; then
    info "Tools available in $TOOLS_LINK/bin"
  else
    warn "nix build of CLI tools failed (see above). Re-run: $DOTFILES_DIR/install.sh"
  fi
}

# --- OpenCode 2 (npm) --------------------------------------------------------
# OpenCode 2 ships on npm as @opencode/cli (provides `opencode` and `opencode2`).
# A user prefix avoids needing write access to the global npm dir.
NPM_PREFIX="$HOME/.local"

install_opencode() {
  if [ "${SKIP_OPENCODE:-}" = "1" ]; then
    info "SKIP_OPENCODE=1 set; skipping OpenCode."
    return
  fi
  if [ -x "$NPM_PREFIX/bin/opencode2" ]; then
    info "OpenCode already installed ($("$NPM_PREFIX/bin/opencode2" --version 2>/dev/null || echo '?'))."
    return
  fi
  if ! have npm; then
    warn "npm not found; skipping OpenCode."
    return
  fi
  info "Installing OpenCode 2 (npm @opencode/cli)..."
  # postinstall selects the platform binary; newer npm skips it unless allowed.
  if npm install -g --prefix "$NPM_PREFIX" --allow-scripts=@opencode/cli @opencode/cli; then
    info "Installed OpenCode $("$NPM_PREFIX/bin/opencode2" --version 2>/dev/null || echo '?')"
  else
    warn "OpenCode install failed (see above). Re-run: $DOTFILES_DIR/install.sh"
  fi
}

# --- Agent skills ------------------------------------------------------------
install_skills() {
  if [ "${SKIP_SKILLS:-}" = "1" ]; then
    info "SKIP_SKILLS=1 set; skipping agent-skills install."
    return
  fi
  [ -x "$DOTFILES_DIR/skills.sh" ] || return
  info "Installing agent skills (via npx skills)..."
  # Non-fatal: an old/missing Node or no network shouldn't abort the install.
  if "$DOTFILES_DIR/skills.sh"; then
    :
  else
    warn "Agent-skills install skipped/failed (see above). Re-run later: $DOTFILES_DIR/skills.sh"
  fi
}

# --- Default shell -----------------------------------------------------------
maybe_set_default_shell() {
  local zsh_path
  zsh_path="$(command -v zsh || true)"
  [ -n "$zsh_path" ] || { warn "zsh not found; skipping default-shell change."; return; }
  if [ "${SHELL:-}" = "$zsh_path" ]; then
    info "zsh is already the default shell."
    return
  fi
  info "To make zsh your default shell, run:  chsh -s $zsh_path"
}

main() {
  have git  || { echo "git is required." >&2; exit 1; }
  have curl || { echo "curl is required." >&2; exit 1; }

  install_oh_my_zsh
  install_p10k
  link_dotfiles
  install_tools
  install_nvm
  install_opencode
  install_skills
  maybe_set_default_shell

  info "Done. Start a new shell or run: exec zsh"
}

main "$@"
