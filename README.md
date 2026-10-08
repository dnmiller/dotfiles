# dotfiles

Personal zsh dotfiles (oh-my-zsh + Powerlevel10k).

## Install

Clone the repo and run the installer:

```sh
git clone https://github.com/dnmiller/dotfiles.git ~/.dotfiles && ~/.dotfiles/install.sh
```

Then start a new shell (or `exec zsh`).

`install.sh` is idempotent and will:

1. Install [oh-my-zsh](https://ohmyz.sh/) if it isn't already present.
2. Install [Powerlevel10k](https://github.com/romkatv/powerlevel10k) if it isn't already present.
3. Symlink everything in [`home/`](home/) into `$HOME` (e.g. `~/.zshrc`,
   `~/.zprofile`, `~/.p10k.zsh`), backing up any existing files to
   `~/.dotfiles-backup/<timestamp>/`.
4. Bootstrap Node via [nvm](https://github.com/nvm-sh/nvm) (installs the latest
   LTS) if the current Node is older than 22.20 — needed by the skills CLI.
   Skip with `SKIP_NVM=1`.
5. Install agent skills from [`skills.txt`](skills.txt) (skip with `SKIP_SKILLS=1`,
   which also skips the Node/nvm bootstrap).

If zsh isn't your default shell yet, the installer prints the `chsh` command to run.

## Agent skills

Agent skills (for [Cursor](https://cursor.com) and other agents) are installed
with the [`skills`](https://github.com/vercel-labs/skills) CLI via `npx`, driven
by a declarative manifest, [`skills.txt`](skills.txt). Add a source per line:

```
# owner/repo, a full git/GitHub/GitLab URL, or a local path.
# Optionally list specific skill names after the source; omit for all.
mattpocock/skills
```

Then install / update:

```sh
./skills.sh            # install everything in skills.txt   (alias: skills-sync)
./skills.sh update     # update installed skills to latest  (alias: skills-update)
```

By default skills are installed **globally for Cursor** (`~/.cursor/skills/`).
Override with env vars: `SKILLS_AGENTS="cursor claude-code"` (space-separated,
see the CLI's supported agents) or `SKILLS_SCOPE=project` (writes to
`./.agents/skills/` in the current directory instead).

> Requires **Node ≥ 22.20.0** (the `skills` CLI's minimum). `install.sh`
> bootstraps this automatically via nvm; `skills.sh` run on its own checks the
> version and exits with guidance if your Node is too old.

## Layout

```
.
├── install.sh      # single-command installer (symlinks into $HOME)
├── skills.sh       # install/update agent skills from skills.txt
├── skills.txt      # agent-skills manifest (one source per line)
├── home/           # files that get symlinked into $HOME
│   ├── .zshrc
│   ├── .zprofile
│   └── .p10k.zsh
└── README.md
```

## Making changes

Because the files are symlinked, editing `~/.zshrc` edits the file in this repo.
Commit and push as usual. A `dotfiles` alias is provided for convenience:

```sh
dotfiles status        # == git -C ~/.dotfiles status
dotfiles add -A && dotfiles commit -m "..." && dotfiles push
```

> Set `DOTFILES` in your environment if you clone somewhere other than `~/.dotfiles`.

## Notes

- SSH keys are intentionally not managed here. Generate per-host:
  `ssh-keygen -t ed25519 -C "<host>"` and add the public key to GitHub.
- To reconfigure the prompt: `p10k configure` (writes `~/.p10k.zsh`).
