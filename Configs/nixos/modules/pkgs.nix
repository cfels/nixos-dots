{ inputs, pkgs, ... }:
{
  # dildo
  #programs.fish.enable = true;
  #programs.hyprland = {
  #  enable = true;
  #  package = pkgs.hyprland;
  #};

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

 # nixpkgs.config.permittedInsecurePackages = [
 # "librewolf-151.0.2-1"
 # "librewolf-unwrapped-151.0.2-1"
 # ];
  
  services.flatpak.enable = true;

  environment.systemPackages = with pkgs; [
vim
wget
parted
fastfetch
pinentry-qt
neovim
librewolf
pkgs.qt6.qtdeclarative
kiro-cli
git
usbutils
git-filter-repo
git-crypt
kitty
nerd-fonts.symbols-only
cliphist
wl-clipboard
nerd-fonts.iosevka
doas
fish
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
zed-editor
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
pkg-config
pango
gdk-pixbuf
graphene
clang-tools
python3
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
android-tools
binutils
gitleaks
prismlauncher
jdk21
sl
libva-utils
pnpm
steam
depotdownloader
qemu
obsidian
#google-chrome # chrome bloat
];
  programs.nix-ld.enable = true;
}
