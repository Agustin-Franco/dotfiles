# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
bindkey -v
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/nebo/.zshrc'

#
# Plugins & Themes
#

# Enable zsh-autosuggestions
source $HOME/.config/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
# Enable zsh-syntax-highlighting (must be sourced last)
source $HOME/.config/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# Enable zsh-sudo
source $HOME/.config/zsh/zsh-sudo/sudo.plugin.zsh
# Oh my posh Theme
eval "$(oh-my-posh init zsh --config $HOME/.config/ohmyposh/ohmyposhTheme.toml)"

 plugins=(
  zsh-autosuggestions
  zsh-syntax-highlighting
  sudo
 )

autoload -Uz compinit
compinit
# End of lines added by compinstall

#Aliases for commands/apps
alias install='sudo pacman -S --needed $(pacman -Slq | sort -u | fzf -m --prompt="Install > " --preview "pacman -Si {}")'
alias uninstall='sudo pacman -Rns $(pacman -Qq | fzf -m --prompt="Uninstall > " --preview "pacman -Qi {}")'
alias update='sudo timeshift --create --comments "Pre-update snapshot" && sudo grub-mkconfig -o /boot/grub/grub.cfg && sudo pacman -Syu'

alias vim='nvim'
alias ls='lsd'
alias logout='hyprctl dispatch exit'
alias code='vscodium'





export PATH=$PATH:/home/nebo/.spicetify
