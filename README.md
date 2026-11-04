<div align="center">

# 🌸🍙🌸 Moxi's Dots 🌸🍙🌸
**An beautiful Quickshell rice i crafted** <br>
it uses **Quickshell** + **Hyprland**, **Hyprlock** for it's main features and components


### Installation

</div>

```
nix-shell -p stow git wget aria2
cd ~/nixos-dots/
git submodule update --init --recursive
bash ./installer
```

Wallpapers (including Velina's videos, original sound, posters, and particle texture) live in [dots-wallpapers](https://github.com/cfels/dots-wallpapers), checked out at `Configs/walls/walls`. The installer initializes this submodule too. After pulling dotfiles updates, run `git submodule update --init --recursive` to fetch the pinned assets. To update the assets independently, pull inside that submodule and commit its new revision in the dotfiles repo. `~/walls` keeps its existing Stow link.

Secure boot for ppl with fresh install:

```sh
bash ./installer --secure-boot
```

existing installs can use: `sudo grub-secure-setup`.

<div align="center">

for restoring ur old setup use `-h, --help` flag it'll tell u what to do

### Showcase

**Full Showcase via this Youtube link:**  https://youtu.be/L3jM4u6-SnM

### Screenshots
  
| Blank Workspace |
|:---:|
| <img src="./assets/blank.png" width="750"> |
  
</div>

| App Launcher | Panel | Lyrics |
|:---:|:---:|:---:|
| ![App Launcher](./assets/applauncher.png) | ![Panel](./assets/player.png) | ![Lyrics](./assets/player_lyrics.png) |

| Terminal | Clipboard | Emoji Picker |
|:---:|:---:|:---:|
| ![Terminal](./assets/term.png) | ![Clipboard](./assets/clipboard.png) | ![Emoji Picker](./assets/emojipicker.png) |

| Logout |
|:---:|
| ![Logout](./assets/logout.png) |


Velina animated wallpaper: [PremiumWalls setup and controls](Configs/config/.config/quickshell/moxi/wallpaper/README.md).
