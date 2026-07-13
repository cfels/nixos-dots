# init
starship init fish | source

fastfetch

# disable greet
set --erase fish_greeting
set fish_greeting

# exports
set -gx PATH $HOME/.local/bin $PATH

# aliases
alias nixbuild="doas nixos-rebuild switch --flake /etc/nixos#moxiu"
alias nixconf="doas nvim ~/nixos-dots/Configs/nixos"
alias nixupdate="doas nix flake update --flake /etc/nixos"
alias vac="vac-status"
alias vps="ssh root@REDACTED_IP"
alias server="ssh -p 2222 root@REDACTED_IP"
alias rm='rm -i'
alias sudo='doas'
