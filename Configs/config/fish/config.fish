# init
starship init fish | source

fastfetch

# disable greet
set --erase fish_greeting
set fish_greeting

# exports
set -gx PATH $HOME/.local/bin $PATH

# aliases
alias nixbuild="rm -rf ~/.config/gtk-3.0/settings.ini ~/.gtkrc-2.0 ~/.config/gtk-4.0/settings.ini && doas nixos-rebuild switch --flake /etc/nixos#moxiu"
alias nixconf="doas nvim ~/nixos-dots/Configs/nixos"
alias nixupdate="doas nix flake update --flake /etc/nixos"
alias vac="vac-status"
