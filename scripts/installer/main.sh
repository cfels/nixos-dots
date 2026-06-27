#!/usr/bin/env bash

set -e

cat <<"EOF"
   _  _______  __    ___  ____  __________  _____  _______________   __   __   _______ 
  / |/ /  _/ |/_/___/ _ \/ __ \/_  __/ __/ /  _/ |/ / __/_  __/ _ | / /  / /  / __/ _ \
 /    // /_>  </___/ // / /_/ / / / _\ \  _/ //    /\ \  / / / __ |/ /__/ /__/ _// , _/
/_/|_/___/_/|_|   /____/\____/ /_/ /___/ /___/_/|_/___/ /_/ /_/ |_/____/____/___/_/|_| v1.0
                                                                                          by moxiu (cfels on github)
EOF

# restore and rollback flag
if [[ "$1" = "--rollback_restore" || "$1" = "-rr" ]]; then
  echo "rolling u back and restoring..."
  exec "$HOME/nixos-dots/scripts/installer/just_to_be_safe/rollback.sh && $HOME/nixos-dots/scripts/installer/just_to_be_safe/restore.sh"
  echo "both script's finished it's work"
  exit 0
fi

# help flag
if [[ "$1" = "--help" || "$1" = "-h" ]]; then
  cat <<"EOF"

--[[
   _  _______  __    ___  ____  __________  __ ________   ___ 
  / |/ /  _/ |/_/___/ _ \/ __ \/_  __/ __/ / // / __/ /  / _ \
 /    // /_>  </___/ // / /_/ / / / _\ \  / _  / _// /__/ ___/
/_/|_/___/_/|_|   /____/\____/ /_/ /___/ /_//_/___/____/_/    
                                                              
--]]

  USAGE:
   --help, -h = show help (who would guess that right?)
   --rollback_restore, -rr = nix rollback and restore ur configs

that's it
EOF
  exit 0
fi

echo "check stuff"
"$HOME/nixos-dots/scripts/installer/checkstuff.sh"

echo "execute backup script"
"$HOME/nixos-dots/scripts/installer/just_to_be_safe/backup.sh"

echo "apply configs"
"$HOME/nixos-dots/scripts/installer/applyconfigs_stow.sh"

echo "setup browser (placeholder for now)"
"$HOME/nixos-dots/scripts/installer/setupbrowser.sh"

echo "DONE! with no issue's i guess"
