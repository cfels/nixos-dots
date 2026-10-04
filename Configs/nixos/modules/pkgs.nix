{ inputs, pkgs, ... }:
{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  services.flatpak.enable = true;
  programs.hyprland.enable = true;
  programs.gpu-screen-recorder.enable = true;
  services.gnome.gnome-keyring.enable = true;
  
  # for virtualbox
  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ "moxiu" ];

  environment.systemPackages = with pkgs; [
heroic
gamemode
gamescope
vscodium
virtualbox
seanime
minisign
age
tdf
imagemagick
libsecret
matugen
gnome-keyring
hyprlock
quickshell
vim
unrar
vlc
uv
fetch
android-tools
wget
parted
fastfetch
pinentry-qt
neovim
librewolf
pkgs.qt6.qtdeclarative
git
usbutils
git-filter-repo
git-crypt
kitty
nerd-fonts.symbols-only
cliphist
wl-clipboard
grim
slurp
awww
mpvpaper
nerd-fonts.iosevka
doas
jdk25
fish
tldr
pkg-config
kdePackages.spectacle
starship
docker
unzip
zip
binwalk
ghidra
texlivePackages.noto-emoji
aria2
clang
gcc
kdePackages.kcalc
plasmusic-toolbar
nh
pavucontrol
playerctl
qt6Packages.qt6ct
libsForQt5.qt5ct
catppuccin-qt5ct
bibata-cursors
pulseaudio
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
hicolor-icon-theme
libnotify
jq
peaclock
lavat
rustup
gtk4
glib
glibc.dev
cairo
pango
gdk-pixbuf
graphene
clang-tools
(python3.withPackages (ps: [ ps.pip ]))
meson
ninja
#pipx
stow
tree
nodejs
bun
tshark
cmake
gnumake
deno
dig
go
mpv
nixd
nil
obs-studio
nvme-cli
binutils
gitleaks
prismlauncher
jdk21
sl
libva-utils
pnpm
depotdownloader
];
  programs.nix-ld.enable = true;
}
