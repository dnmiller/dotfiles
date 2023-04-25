Install oh-my-zsh: 
```
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

Install Powerlevel10k:
```
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
```

Then dotfiles:
```
alias config='/usr/bin/git --git-dir=$HOME/.dotfiles/.git/ --work-tree=$HOME' && echo ".dotfiles" >> .gitignore && git clone --bare git@github.com:dnmiller/dotfiles.git $HOME/.dotfiles/.git
config checkout
```
