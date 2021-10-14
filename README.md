Setting up a new Mac:

1. Run system update.
2. Download iTerm2, install in Applications.
3. Install homebrew.
4. Make new ssh key and add to github/bitbucket.
5. Install oh-my-zsh.
6. Clone dotfiles.

Setting up a new Linux box:
1. Run system update.
2. Create a new SSH key and add it to GitHub.
3. At command prompt: `alias config='/usr/bin/git --git-dir=$HOME/.dotfiles/.git/ --work-tree=$HOME' && echo ".dotfiles" >> .gitignore`
4. Clone the repo: `git clone --bare git@github.com:dnmiller/dotfiles.git $HOME/.dotfiles.git`
5. Run `config checkout`.
