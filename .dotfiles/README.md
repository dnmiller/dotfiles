General:
1. Update everything.
2. Install [Oh-My-Zsh](https://ohmyz.sh/#install).
3. Install [Powerlevel10k](https://github.com/romkatv/powerlevel10k#oh-my-zsh)
4. Create new SSH keys and add to GitHub/Bitbucket.

Setting up a new Mac:
1. Run system update.
2. Download iTerm2, install in Applications.
3. Install homebrew.
4. Make new ssh keys and add to github/bitbucket.
5. Install [Oh-My-Zsh](https://ohmyz.sh/#install).
6. Clone dotfiles: `git clone --bare git@github.com:dnmiller/dotfiles.git ~/.dotfiles/.git`
7. Add alias: `alias config='/usr/bin/git --git-dir=$HOME/.dotfiles/.git/ --work-tree=$HOME'`
8. Checkout dotfiles: `config checkout`

Setting up a new Linux box:
1. Run system update.
2. Install [Oh-My-Zsh](https://ohmyz.sh/#install).
3. Install [Powerlevel10k](https://github.com/romkatv/powerlevel10k#oh-my-zsh)
4. Create a new SSH key and add it to GitHub.
5. At command prompt: `alias config='/usr/bin/git --git-dir=$HOME/.dotfiles/.git/ --work-tree=$HOME' && echo ".dotfiles" >> .gitignore`
6. Clone the repo: `git clone --bare git@github.com:dnmiller/dotfiles.git $HOME/.dotfiles.git`
7. Run `config checkout`.
