#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

alias install='sudo pacman -S --needed $(pacman -Slq | sort -u | fzf -m --prompt="Install > " --preview "pacman -Si {}")'

alias uninstall='sudo pacman -Rns $(pacman -Qq | fzf -m --prompt="Uninstall > " --preview "pacman -Qi {}")'

alias vim='nvim'

eval "$(oh-my-posh init bash --config $HOME/.config/ohmyposh/base.toml)"
