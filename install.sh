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

# "container" or "host"; set DOTFILES_ENV to override the guess.
detect_env() {
  if [ -n "${DOTFILES_ENV:-}" ]; then
    printf '%s\n' "$DOTFILES_ENV"
  elif [ -e /.dockerenv ] || [ -e /run/.containerenv ] \
      || [ -n "${REMOTE_CONTAINERS:-}${CODESPACES:-}${container:-}" ]; then
    echo container
  else
    echo host
  fi
}
DOTFILES_ENV="$(detect_env)"
case "$DOTFILES_ENV" in
  container|host) ;;
  *) echo "DOTFILES_ENV must be 'container' or 'host' (got '$DOTFILES_ENV')." >&2; exit 1 ;;
esac

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
  # home/.config is shared with other apps, so its children are linked
  # individually (e.g. ~/.config/nvim) instead of replacing ~/.config.
  local entry name
  shopt -s dotglob nullglob
  for entry in "$HOME_SRC"/*; do
    name="$(basename "$entry")"
    if [ "$name" = ".config" ]; then
      mkdir -p "$HOME/.config"
      local child
      for child in "$entry"/*; do
        link_file "$child" "$HOME/.config/$(basename "$child")"
      done
    else
      link_file "$entry" "$HOME/$name"
    fi
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
  local pkg=default
  [ "$DOTFILES_ENV" = container ] && pkg=container
  info "Building CLI tools from flake.nix (#$pkg)..."
  mkdir -p "$(dirname "$TOOLS_LINK")"
  if nix --extra-experimental-features 'nix-command flakes' \
      build "$DOTFILES_DIR#$pkg" --out-link "$TOOLS_LINK"; then
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
  local bin="$NPM_PREFIX/bin/opencode2"
  if [ -x "$bin" ]; then
    info "OpenCode already installed ($("$bin" --version 2>/dev/null || echo '?'))."
  elif ! have npm; then
    warn "npm not found; skipping OpenCode."
    return
  else
    info "Installing OpenCode 2 (npm @opencode/cli)..."
    # postinstall selects the platform binary; newer npm skips it unless allowed.
    if npm install -g --prefix "$NPM_PREFIX" --allow-scripts=@opencode/cli @opencode/cli; then
      info "Installed OpenCode $("$bin" --version 2>/dev/null || echo '?')"
    else
      warn "OpenCode install failed (see above). Re-run: $DOTFILES_DIR/install.sh"
      return
    fi
  fi
  # Fails to load on opencode >= 2.0.4 (ephraimduncan/opencode-cursor#39);
  # replaced by the cursor provider below.
  if grep -qs '"opencode-cursor-oauth"' "$HOME/.config/opencode/opencode.json"; then
    "$bin" plugin remove opencode-cursor-oauth </dev/null >/dev/null \
      || warn "Could not remove the broken opencode-cursor-oauth plugin."
  fi
}

# --- Cursor models in opencode -----------------------------------------------
# cursor-opencode-provider (an opencode plugin, provider "cursor"), pinned in
# opencode/base.json; opencode installs it on start. bin/cursor-provider merges
# that template into opencode's config and updates the pin.
install_cursor_provider() {
  if [ "${SKIP_CURSOR_PROVIDER:-}" = "1" ]; then
    info "SKIP_CURSOR_PROVIDER=1 set; skipping Cursor provider."
    return
  fi
  mkdir -p "$NPM_PREFIX/bin"
  link_file "$DOTFILES_DIR/bin/cursor-provider" "$NPM_PREFIX/bin/cursor-provider"

  # Earlier setup ran cursor-api-proxy behind a bin/cursor-proxy script.
  if [ -L "$NPM_PREFIX/bin/cursor-proxy" ] && [ ! -e "$NPM_PREFIX/bin/cursor-proxy" ]; then
    rm "$NPM_PREFIX/bin/cursor-proxy"
  fi
  local pidfile="${XDG_STATE_HOME:-$HOME/.local/state}/cursor-proxy/proxy.pid"
  if [ -f "$pidfile" ]; then
    kill "$(cat "$pidfile")" 2>/dev/null && info "Stopped cursor-api-proxy."
    rm -f "$pidfile"
  fi
  if [ -e "$NPM_PREFIX/bin/cursor-api-proxy" ]; then
    info "Removing cursor-api-proxy (replaced by cursor-opencode-provider)..."
    npm uninstall -g --prefix "$NPM_PREFIX" cursor-api-proxy >/dev/null \
      || warn "Could not uninstall cursor-api-proxy."
  fi

  # Plugin pin and build/plan/ask agents from opencode/base.json, merged into
  # opencode's config (other keys are kept).
  "$NPM_PREFIX/bin/cursor-provider" apply-config \
    || warn "Could not apply opencode/base.json. Re-run: cursor-provider apply-config"
  # Signing in is interactive, so it can't happen here.
  info "To use Cursor models in opencode: run /connect -> Cursor inside opencode."
  info "Update the pinned provider: cursor-provider update (roll back: cursor-provider update <version>)"
}

# --- Local model (hosts) -----------------------------------------------------
# Qwen3-Coder-Next on llama.cpp's llama-server (bin/local-llm), added to opencode
# as provider "llama-cpp". Hosts only, and only with memory for the model
# (~49 GB) plus context; LOCAL_LLM=1 or LOCAL_LLM=0 overrides that.
mem_gib() {
  if [ "$(uname)" = Darwin ]; then
    echo $(( $(sysctl -n hw.memsize) / 1073741824 ))
  else
    awk '/^MemTotal:/ { print int($2 / 1048576) }' /proc/meminfo
  fi
}

install_local_llm() {
  local want="${LOCAL_LLM:-}"
  if [ -z "$want" ]; then
    want=0
    [ "$DOTFILES_ENV" = host ] && [ "$(mem_gib)" -ge 64 ] && want=1
  fi
  if [ "$want" != 1 ]; then
    info "Skipping the local model (needs a host with 64 GB+ of memory; LOCAL_LLM=1 forces it)."
    return
  fi
  mkdir -p "$NPM_PREFIX/bin"
  link_file "$DOTFILES_DIR/bin/local-llm" "$NPM_PREFIX/bin/local-llm"
  "$NPM_PREFIX/bin/local-llm" apply-config \
    || warn "Could not add the local model to opencode. Re-run: local-llm apply-config"
  info "Local model: run local-llm start (the first start downloads ~49 GB), then pick llama-cpp/qwen3-coder-next in opencode's /models."
}

# --- CodeGraph (npm) ---------------------------------------------------------
# Code-intelligence MCP server. `codegraph install` wires it into Cursor and
# opencode; it's idempotent, so it runs every time in case either agent's
# config was reset. Per-project: `codegraph init`.
install_codegraph() {
  if [ "${SKIP_CODEGRAPH:-}" = "1" ]; then
    info "SKIP_CODEGRAPH=1 set; skipping CodeGraph."
    return
  fi
  local bin="$NPM_PREFIX/bin/codegraph"
  export CODEGRAPH_TELEMETRY=0
  if [ -x "$bin" ]; then
    info "CodeGraph already installed ($("$bin" --version 2>/dev/null || echo '?'))."
  elif ! have npm; then
    warn "npm not found; skipping CodeGraph."
    return
  else
    info "Installing CodeGraph (npm @colbymchenry/codegraph)..."
    if ! npm install -g --prefix "$NPM_PREFIX" @colbymchenry/codegraph; then
      warn "CodeGraph install failed (see above). Re-run: $DOTFILES_DIR/install.sh"
      return
    fi
  fi
  # Persisted opt-out: MCP servers started by agents may not see shell env.
  "$bin" telemetry off >/dev/null || warn "Could not disable CodeGraph telemetry."
  info "Wiring CodeGraph MCP server into Cursor and opencode..."
  "$bin" install --yes --target cursor,opencode </dev/null \
    || warn "codegraph install failed (see above). Re-run: $bin install"
}

# --- RTK (Rust Token Killer) -------------------------------------------------
# Shell-output compressor for agents (https://github.com/rtk-ai/rtk). Its
# installer verifies checksums and drops the binary in ~/.local/bin. Hooks:
# Cursor (~/.cursor/hooks.json) and an opencode plugin. `--opencode` also sets
# up Claude Code unless limited by --hook-only --no-patch. Both inits are
# idempotent, and their output is only shown on failure because it always
# includes Claude Code "manual step" instructions.
install_rtk() {
  if [ "${SKIP_RTK:-}" = "1" ]; then
    info "SKIP_RTK=1 set; skipping RTK."
    return
  fi
  local bin="$NPM_PREFIX/bin/rtk" out
  if [ -x "$bin" ]; then
    info "RTK already installed ($("$bin" --version 2>/dev/null || echo '?'))."
  else
    info "Installing RTK..."
    if ! curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh \
        | RTK_INSTALL_DIR="$NPM_PREFIX/bin" sh; then
      warn "RTK install failed (see above; set RTK_VERSION=vX.Y.Z if GitHub rate-limited). Re-run: $DOTFILES_DIR/install.sh"
      return
    fi
  fi
  info "Wiring RTK hooks into Cursor and opencode..."
  out="$("$bin" init -g --agent cursor </dev/null 2>&1)" \
    || warn "rtk init (cursor) failed:"$'\n'"$out"
  out="$("$bin" init -g --opencode --hook-only --no-patch </dev/null 2>&1)" \
    || warn "rtk init (opencode) failed:"$'\n'"$out"
}

# --- Caveman (opencode) ------------------------------------------------------
# Terse-reply mode for opencode (https://github.com/JuliusBrussee/caveman): its
# own opencode installer adds a plugin, skills, /caveman commands, cavecrew
# subagents and an always-on rule block in ~/.config/opencode/AGENTS.md. Only
# that integration: caveman's CLI and proxy (which collects usage stats) are
# not installed. The installer needs a local checkout, kept at the pinned tag;
# it is idempotent and refreshes its own files, so it runs every time.
CAVEMAN_REF="v4.0.1"

install_caveman() {
  if [ "${SKIP_CAVEMAN:-}" = "1" ]; then
    info "SKIP_CAVEMAN=1 set; skipping caveman."
    return
  fi
  have node || { warn "node not found; skipping caveman."; return; }
  have opencode || [ -x "$NPM_PREFIX/bin/opencode" ] || { info "opencode not installed; skipping caveman."; return; }
  local dir="$HOME/.local/state/dotfiles/caveman"
  if [ "$(git -C "$dir" describe --tags --exact-match 2>/dev/null)" != "$CAVEMAN_REF" ]; then
    info "Fetching caveman $CAVEMAN_REF..."
    rm -rf "$dir"
    git -c advice.detachedHead=false clone -q --depth 1 --branch "$CAVEMAN_REF" https://github.com/JuliusBrussee/caveman.git "$dir" \
      || { warn "caveman download failed. Re-run: $DOTFILES_DIR/install.sh"; return; }
  fi
  info "Installing caveman into opencode..."
  (cd "$dir" && DO_NOT_TRACK=1 node installer/install.js --only opencode --non-interactive >/dev/null) \
    || warn "caveman install failed. Re-run: cd $dir && node installer/install.js --only opencode"
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
  info "Installing for a $DOTFILES_ENV (override with DOTFILES_ENV=container|host)."

  install_oh_my_zsh
  install_p10k
  link_dotfiles
  install_tools
  install_nvm
  install_opencode
  install_cursor_provider
  install_local_llm
  install_codegraph
  install_rtk
  install_caveman
  install_skills
  maybe_set_default_shell

  info "Done. Start a new shell or run: exec zsh"
}

main "$@"
