#!/usr/bin/env bash

# Check arguments passed from lf ($1 to $5)
file=$1
w=$2
h=$3
x=$4
y=$5

# Ensure width, height, x, and y are valid integers to prevent printf errors
[[ "$w" =~ ^[0-9]+$ ]] || w=0
[[ "$h" =~ ^[0-9]+$ ]] || h=0
[[ "$x" =~ ^[0-9]+$ ]] || x=0
[[ "$y" =~ ^[0-9]+$ ]] || y=0

# Handle image preview using kitty icat safely if dimensions are provided
if [[ "$w" -gt 0 && "$h" -gt 0 ]] && [[ "$(file -Lb --mime-type "$file")" =~ ^image ]]; then
    kitty +kitten icat --silent --stdin no --transfer-mode file --place "${w}x${h}@${x}x${y}" "$file" < /dev/null > /dev/tty
    exit 0
fi

# Fallback preview handling for other file types
case "$file" in
    *.png|*.jpg|*.jpeg|*.gif) 
        cat "$file" ;;
    *.pdf) 
        pdftotext "$file" - ;;
    *.zip) 
        zipinfo "$file" ;;
    *.tar.gz|*.tgz) 
        tar -ztvf "$file" ;;
    *.tar.bz2|*.tbz2) 
        tar -jtvf "$file" ;;
    *.tar) 
        tar -tvf "$file" ;;
    *) 
        if command -v bat &>/dev/null; then
            bat --color=always --style=plain --pager=never "$file"
        elif command -v pistol &>/dev/null; then
            pistol "$file"
        else
            cat "$file"
        fi
        ;;
es:
