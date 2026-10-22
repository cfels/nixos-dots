{ inputs, pkgs, ... }:
{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  services.flatpak.enable = true;
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };
  programs.gpu-screen-recorder.enable = true;
  programs.droidcam.enable = true;
  services.gnome.gnome-keyring.enable = true;

  services.mullvad-vpn = {
    enable = true;
    gui.enable = true;
  };
  
  environment.systemPackages = with pkgs; [
universal-android-debloater
v4l-utils
file
pipes-rs
mesa-demos
vulkan-tools
mangohud
qbittorrent
goverlay
rocmPackages.rocm-smi # for btop to show gpu stats
heroic
gamemode
gamescope
seanime
tokei
kdePackages.ark
kdePackages.dolphin
tdf
imagemagick-native
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
android-studio
android-tools
filezilla
wget
gum
parted
fastfetch
pinentry-qt
(pkgs.callPackage ../packages/neovim.nix { })
librewolf
pkgs.qt6.qtdeclarative
git
usbutils
mold
cachix
ccache
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
p7zip-native
(lib.hiPrio zstd-native)
(lib.hiPrio xz-native)
atool
claude-code
jq
ffmpeg-native
exiftool
udiskie
mpv
fzf
fd
bat
zoxide
hicolor-icon-theme
libnotify
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
nixd
nil
obs-studio
nvme-cli
binutils
gitleaks
jdk21
sl
libva-utils
pnpm
depotdownloader
];
  programs.nix-ld.enable = true;
}
