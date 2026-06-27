{ inputs, pkgs, ... }:
{
  # dildo
  programs.fish.enable = true;
  programs.hyprland = {
    enable = true;
    package = pkgs.hyprland;
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  nixpkgs.config.permittedInsecurePackages = [
  "librewolf-151.0.2-1"
  "librewolf-unwrapped-151.0.2-1"
  ];

  environment.systemPackages = with pkgs; [
vim
wget
fastfetch
neovim
librewolf
hyprland
git
kitty
cliphist
wl-clipboard
nerd-fonts.iosevka
doas
fish
discord
tldr
kdePackages.spectacle
starship
docker
unzip
zip
texlivePackages.noto-emoji
aria2
clang
gcc
telegram-desktop
nh
waybar
wlogout
swaynotificationcenter
pavucontrol
playerctl
rofi
slurp
grim
awww
qt6Packages.qt6ct
libsForQt5.qt5ct
catppuccin-qt5ct
kdePackages.qtstyleplugin-kvantum
bibata-cursors
pulseaudio
nwg-look
sassc
kdePackages.breeze-icons
swappy
cava
lf
ctpv
ffmpegthumbnailer
rsync
p7zip
atool
jq
ffmpeg
exiftool
udiskie
mpv
fzf
fd
bat
zoxide
papirus-icon-theme
hyprlock
hicolor-icon-theme
whitesur-icon-theme
libnotify
jq
hyprshot
peaclock
lavat
rustup
gtk4
glib
cairo
pkg-config
pango
gdk-pixbuf
graphene
python3
pipx
stow
tree
];
  programs.nix-ld.enable = true;
}
