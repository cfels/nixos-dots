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
alias sudo='doas'
alias conf='nvim $HOME/nixos-dots/Configs/config/.config'

# make rm safer
function rm
    command rm -i $argv
end
funcsave rm >/dev/null
