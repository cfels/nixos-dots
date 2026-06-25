#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS="$REPO/Configs"
CFG="$CONFIGS/config"

R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' B='\033[0;34m' N='\033[0m'
ok()   { echo -e "${G}[OK]${N} $*"; }
info() { echo -e "${B}[--]${N} $*"; }
warn() { echo -e "${Y}[!!]${N} $*"; }
die()  { echo -e "${R}[ERR]${N} $*"; exit 1; }

command -v stow >/dev/null 2>&1 || die "stow not installed"
[[ -d "$CONFIGS" ]] || die "Configs dir not found at $CONFIGS"

# 1. circular symlinks
info "Checking circular symlinks..."
[[ -L "/etc/nixos/nixos" ]]     && sudo rm "/etc/nixos/nixos" && warn "Removed /etc/nixos/nixos loop"
[[ -L "$CONFIGS/nixos/nixos" ]] && rm "$CONFIGS/nixos/nixos" && warn "Removed Configs/nixos/nixos loop"
ok "Circular symlinks clean"

# 2. remove absolute symlinks + socket files from repo (home-manager/runtime stuff)
info "Removing absolute/socket symlinks from repo..."
# Use process substitution instead of pipe to avoid set -e issues
while IFS= read -r f; do
    t="$(readlink "$f")"
    [[ "$t" == /* ]] && rm "$f" && info "  rm abs: ${f#"$CONFIGS/"}"
done < <(find "$CFG" "$CONFIGS/icons" -type l 2>/dev/null)
rm -f "$CFG/discord/SingletonLock" "$CFG/discord/SingletonCookie" "$CFG/discord/SingletonSocket" 2>/dev/null || true
ok "Done"

# 3. clean runtime/cache junk from config package
info "Cleaning cache/runtime from Configs/config/ ..."
for d in \
    "Code/Cache" "Code/CachedData" "Code/CachedExtensionVSIXs" "Code/CachedProfilesData" \
    "Code/CachedConfigurations" "Code/Code Cache" "Code/DawnGraphiteCache" \
    "Code/DawnWebGPUCache" "Code/GPUCache" "Code/Crashpad" "Code/logs" \
    "Code/Session Storage" "Code/Local Storage" "Code/blob_storage" "Code/Shared Dictionary" "Code/Backups" \
    "discord/Cache" "discord/Code Cache" "discord/DawnGraphiteCache" "discord/DawnWebGPUCache" \
    "discord/GPUCache" "discord/Crashpad" "discord/logs" "discord/Session Storage" \
    "discord/Local Storage" "discord/blob_storage" "discord/Shared Dictionary" \
    "discord/VideoDecodeStats" "discord/Service Worker" "discord/WebStorage" \
    "discord/1.0.141" "discord/module_data" "discord/shared_proto_db" \
    "discord/sentry" "discord/discord_asset_cache" \
    "vesktop/sessionData" "vesktop/Crashpad" \
    "session" "Equicord" "pulse" "mozilla" "librewolf" "libaccounts-glib" \
    "geeqie" "btop/themes" "kate" "kdedefaults" "KDE" "dconf" "fontconfig/conf.d" "systemd/user"; do
    [[ -e "$CFG/$d" ]] && rm -rf "${CFG:?}/$d" && info "  rm $d"
done
for f in kglobalshortcutsrc plasma-org.kde.plasma.desktop-appletsrc plasmashellrc \
    plasmarc plasmanotifyrc plasma-localerc kwinrc kwinrulesrc kwinoutputconfig.json \
    ksmserverrc ksplashrc kscreenlockerrc kconf_updaterc kactivitymanagerdrc \
    kactivitymanagerd-statsrc kded5rc kded6rc kmenueditrc kiorc ktrashrc ktimezonedrc \
    kwalletrc kservicemenurc konsolerc konsolesshconfig baloofileinformationrc baloofilerc \
    okularrc okularpartrc katerc katevirc kate-externaltoolspluginrc kdeglobals darklyrc \
    dolphinrc gwenviewrc spectaclerc arkrc trashrc user-dirs.dirs user-dirs.locale \
    Trolltech.conf QtProject.conf mimeapps.list powermanagementprofilesrc pavucontrol.ini kcminputrc; do
    [[ -f "$CFG/$f" ]] && rm -f "$CFG/$f" && info "  rm $f"
done
ok "Config package clean"

# 4. fix package structures
# icons needs .icons/ wrapper inside
if [[ -d "$CONFIGS/icons" ]] && [[ ! -d "$CONFIGS/icons/.icons" ]]; then
    mkdir -p "$CONFIGS/icons/.icons"
    for d in "$CONFIGS/icons"/*/; do
        n="$(basename "$d")"; [[ "$n" == ".icons" ]] && continue; mv "$d" "$CONFIGS/icons/.icons/$n"
    done; ok "icons restructured"
fi
# local needs .local/bin/ wrapper
if [[ -d "$CONFIGS/local" ]] && [[ ! -d "$CONFIGS/local/.local" ]]; then
    mkdir -p "$CONFIGS/local/.local"
    [[ -d "$CONFIGS/local/bin" ]]   && mv "$CONFIGS/local/bin"   "$CONFIGS/local/.local/bin"
    [[ -d "$CONFIGS/local/share" ]] && rm -rf "$CONFIGS/local/share"
    [[ -d "$CONFIGS/local/state" ]] && rm -rf "$CONFIGS/local/state"
    ok "local restructured"
fi
[[ -d "$CONFIGS/local/.local/share" ]] && rm -rf "$CONFIGS/local/.local/share"
[[ -d "$CONFIGS/local/.local/state" ]] && rm -rf "$CONFIGS/local/.local/state"

# 5. /etc/nixos
info "Checking /etc/nixos ..."
if [[ -L /etc/nixos ]]; then
    [[ "$(readlink /etc/nixos)" == "$CONFIGS/nixos" ]] \
        && ok "/etc/nixos -> repo (correct)" \
        || { sudo rm /etc/nixos; sudo ln -s "$CONFIGS/nixos" /etc/nixos; ok "Fixed /etc/nixos"; }
elif [[ -d /etc/nixos ]]; then
    warn "/etc/nixos is a real dir — skipping. Fix: sudo mv /etc/nixos /etc/nixos.bak && sudo ln -s $CONFIGS/nixos /etc/nixos"
fi
[[ -f /etc/nixos/flake.nix ]] && ok "flake.nix accessible" || warn "flake.nix not found"

# 6. stow ignore for config
cat > "$CFG/.stow-local-ignore" <<'EOF'
\.sqlite(-shm|-wal)?$
\.bdic$
LOCK$
MANIFEST-
CURRENT$
Singleton
DIPS(-wal)?$
SharedStorage(-wal)?$
Trust Tokens
Cookies-journal$
domainMigrated$
EOF

# 7. clear ~/.icons if real dir (repo has same content)
[[ -d "$HOME/.icons" ]] && [[ ! -L "$HOME/.icons" ]] && rm -rf "$HOME/.icons"

# 8. apply stow
info "Applying stow..."
mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/walls"

stow --dir="$CONFIGS" --target="$HOME/.config" --no-folding --adopt --restow config 2>&1 | grep -v "^Stowing" || true
ok "config stowed"
stow --dir="$CONFIGS" --target="$HOME"         --no-folding         --restow icons  2>&1 | grep -v "^Stowing" || true
ok "icons stowed"
stow --dir="$CONFIGS" --target="$HOME"         --no-folding --adopt --restow local  2>&1 | grep -v "^Stowing" || true
ok "local stowed"
stow --dir="$CONFIGS" --target="$HOME"         --no-folding --adopt --restow walls  2>&1 | grep -v "^Stowing" || true
ok "walls stowed"

# 9. verify
echo; info "Verifying symlinks..."
errs=0
chk() {
    local p="$1" label="$2"
    # check p itself or first symlink inside it
    local target=""
    [[ -L "$p" ]] && target="$(readlink "$p")"
    [[ -z "$target" ]] && target="$(find "$p" -maxdepth 1 -type l 2>/dev/null | head -1 | xargs readlink 2>/dev/null || true)"
    if [[ "$target" == *nixos-dots* ]]; then
        ok "$label -> repo"
    elif [[ -e "$p" ]]; then
        warn "$label exists but NOT linked to repo"; (( errs++ )) || true
    else
        warn "$label MISSING"; (( errs++ )) || true
    fi
}
chk "$HOME/.config/fish"            "~/.config/fish"
chk "$HOME/.config/hypr"            "~/.config/hypr"
chk "$HOME/.config/nvim"            "~/.config/nvim"
chk "$HOME/.config/waybar"          "~/.config/waybar"
chk "$HOME/.icons/Catppuccin-Mocha" "~/.icons/Catppuccin-Mocha"
chk "$HOME/.local/bin/hypremoji"    "~/.local/bin/hypremoji"
[[ -L /etc/nixos/nixos ]] && { warn "CIRCULAR /etc/nixos/nixos still exists!"; (( errs++ )) || true; } || ok "No /etc/nixos loop"
[[ -f /etc/nixos/flake.nix ]] && ok "/etc/nixos/flake.nix readable (nixos-rebuild will work)"

echo
[[ $errs -eq 0 ]] \
    && ok "All done! Edit ~/.config/* files and changes go straight to ~/nixos-dots." \
    || warn "$errs issue(s) — see warnings above."
