# init
starship init fish | source

fastfetch

# disable greet
set --erase fish_greeting
set fish_greeting

# exports
set -gx PATH $HOME/.local/bin $PATH
fish_add_path "/home/moxiu/.bun/bin"

# aliases
alias nixbuild="doas nixos-rebuild switch --flake /etc/nixos#moxiu"
alias nixconf="doas nvim ~/nixos-dots/Configs/nixos"
function nixupdate --description "Update flake inputs and re-pin hyprglass for the new Hyprland"
    doas nix flake update --flake /etc/nixos
    and /etc/nixos/scripts/hyprglass-pin.sh
end
alias vac="vac-status"
alias sudo='doas'
alias conf='nvim $HOME/nixos-dots/Configs/config/.config'
alias icat="kitten icat"
alias changedpi="sudo k1ng_driver"
alias k1ng_driver="sudo k1ng_driver"

# make rm safer
function rm
    command rm -i $argv
end
funcsave rm >/dev/null
