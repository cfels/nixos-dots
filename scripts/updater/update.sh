#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

# ── vars ──────────────────────────────────────────────────────────────────────

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
flake="$repo/Configs/nixos"

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dots-updater"
colors="${XDG_CONFIG_HOME:-$HOME/.config}/matugen/generated/updater-colors.sh"

step='getting things ready'
log=''

# ── tty ───────────────────────────────────────────────────────────────────────

if [[ ! -t 0 || ! -t 1 ]]; then
  printf '%s\n' 'open launch.sh so the updater has its own terminal.' >&2
  exit 1
fi

# ── dependencies ──────────────────────────────────────────────────────────────

for dependency in gum git nix doas nixos-rebuild flock tee mktemp; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    printf 'missing %s. install it, then try again.\n' "$dependency" >&2
    read -r -s -n 1 -p 'press any key to close...' || :
    exit 1
  fi
done

# ── colors ────────────────────────────────────────────────────────────────────

accent='5'
muted='7'
error='1'

if [[ -r "$colors" ]]; then
  # shellcheck source=/dev/null
  source "$colors"
fi

export GUM_SPIN_SPINNER_FOREGROUND="$accent"
export GUM_SPIN_TITLE_FOREGROUND="$accent"
export GUM_CONFIRM_PROMPT_FOREGROUND="$accent"
export GUM_CONFIRM_SELECTED_BACKGROUND="$accent"

# ── helpers ───────────────────────────────────────────────────────────────────

pause() {
  printf '\n'
  gum style --foreground "$muted" 'press any key to close~'
  read -r -s -n 1 || :
}

fail() {
  local status="$1"

  if ((BASH_SUBSHELL > 0)); then
    exit "$status"
  fi

  trap - ERR INT TERM

  printf '\n'
  gum style --foreground "$error" --bold \
    "welp, stopped while $step."

  if [[ "$step" == 'pulling the latest dots' ]]; then
    gum style --foreground "$muted" \
      'check the git output above. local edits might need sorting out first.' \
      "repo: $repo"
  fi

  if [[ -n "$log" ]]; then
    gum style --foreground "$muted" "log: $log"
  fi

  pause
  exit "$status"
}

run_step() {
  local number="$1"
  step="$2"
  shift 2

  printf '\n'

  gum style \
    --foreground "$accent" \
    --bold \
    "$number / 3  $step"

  printf '\n--- %s ---\n' "$step" >>"$log"

  gum spin \
    --spinner dot \
    --title "$step~" \
    --show-output \
    -- \
    bash -o pipefail -c \
    'log=$1; shift; "$@" 2>&1 | tee -a "$log"' \
    bash "$log" "$@"
}

trap 'fail "$?"' ERR
trap 'fail 130' INT
trap 'fail 143' TERM

# ── confirmation ──────────────────────────────────────────────────────────────

clear

gum style \
  --border rounded \
  --border-foreground "$accent" \
  --foreground "$accent" \
  --padding '1 3' \
  'NixOS-Dots updater  '

printf '\n'

if ! gum confirm \
  --affirmative 'yessir' \
  --negative 'nah' \
  'wanna update??'; then

  printf '\n'
  gum style --foreground "$muted" 'oki, update cancelled~'
  exit 0
fi

# clear confirmation screen before showing actual updater
clear

# ── lock / log ────────────────────────────────────────────────────────────────

mkdir -p -- "$state_dir"

exec 9>"$state_dir/update.lock"

if ! flock -n 9; then
  gum style --foreground "$accent" \
    'already updating in another window~'
  pause
  exit 0
fi

log="$(mktemp "$state_dir/update-$(date +%Y%m%d-%H%M%S)-XXXXXX.log")"

cd -- "$repo"

# ── updater UI ────────────────────────────────────────────────────────────────

gum style \
  --border rounded \
  --border-foreground "$accent" \
  --foreground "$accent" \
  --padding '1 3' \
  --margin '0 0 1 0' \
  'NixOS-Dots updater  ' \
  '' \
  'Haiii~ were just updating ur system for u please wait a bit!'

gum style --foreground "$muted" \
  'dots updater process' \
  'latest dots → fresh packages → rebuild & switch' \
  'keep this window open while it does its thing~'

# ── 1 / 3 ─────────────────────────────────────────────────────────────────────

run_step 1 \
  'pulling the latest dots' \
  git pull --ff-only

# ── system config ─────────────────────────────────────────────────────────────

step='reading ur system config'
configuration="$(nix eval --raw --file "$flake/username.nix")"

# ── 2 / 3 ─────────────────────────────────────────────────────────────────────

run_step 2 \
  'updating packages and stuff' \
  nix flake update --flake "$flake"

# ── 3 / 3 ─────────────────────────────────────────────────────────────────────

step='rebuilding and switching the system'

printf '\n'

gum style \
  --foreground "$accent" \
  --bold \
  "3 / 3  $step"

gum style --foreground "$muted" \
  'doas might ask for ur password. building can take a bit, go get a drink :p'

printf '\n--- %s ---\n' "$step" >>"$log"

doas nixos-rebuild switch \
  --flake "$flake#$configuration" \
  2>&1 | tee -a "$log"

# ── done ──────────────────────────────────────────────────────────────────────

printf '\n'

gum style \
  --border rounded \
  --border-foreground "$accent" \
  --foreground "$accent" \
  --padding '1 3' \
  'all done~ ☆' \
  '' \
  'fresh dots, fresh system. enjoy <3'

gum style --foreground "$muted" \
  'new kernel? that part kicks in after a reboot.' \
  "log: $log"

pause
