# PremiumWalls: Velina

Select **Velina.premiumwall.json** from the existing wallpaper picker, or run:

```bash
~/.config/hypr/scripts/wallpaper-set.sh ~/walls/Velina.premiumwall.json
```

The existing Hyprland startup hook calls `wallpaper-restore.sh`, so the selection is restored on the next graphical login. No extra autostart service or player is needed. Select any ordinary image/video to disable Velina.

## Playback

`WallpaperCanvas` presents the first ready wallpaper directly, without revealing it over an empty surface. Subsequent selections keep the existing two-slot wallpaper reveal. `WallpaperMedia` delegates `.premiumwall.json` files to `VelinaWallpaper`; ordinary image, GIF, and video playback retains its existing route.

Velina progresses through `INITIALIZING`, `OPENING`, `TRANSITIONING`, and `SHOWCASE_LOOP`. Fullscreen applications pause the decoder and QML effects through `PAUSED`; failures enter `ERROR` and are reported through wallpaper IPC/logs. The small `PremiumVideo` component pre-decodes a frame and pauses before publishing readiness. It resumes that frame without seeking when already at zero, ignores empty video-sink frames, and holds the opening until the showcase delivers a playback frame. `EndOfMedia` starts the handoff, and the showcase's first presented frame completes it. `VideoOutput.KeepLastFrame` and the original-image poster protect against decoder startup/rewind gaps. The opening decoder is destroyed after the handoff. One native Qt looping decoder remains; no browser or Spine runtime runs on the desktop.

The session helper reserves an opening once per output using exclusive file creation under `$XDG_RUNTIME_DIR/moxi-wallpaper/premium-sessions/`. The directory is keyed by `HYPRLAND_INSTANCE_SIGNATURE`, which changes when Hyprland starts. Other compositors use `XDG_SESSION_ID` plus the Wayland/X display. Quickshell restarts, hot reloads, wallpaper reselection, window changes, and screen unlock do not reset the reservation. Each output can show its opening; only one output reserves sound. A reservation is made before decoding, so a crash during startup skips the rest of that opening rather than replaying its sound. A newly connected output can play its own opening during the same graphical session.

The sound stays in the opening's MediaPlayer, preserving its native A/V synchronization. If the desktop audio device appears late at login, the opening holds its first frame until an output is available. Its AudioOutput follows Qt MediaDevices' default output, including device changes. The showcase remains muted. Fullscreen detection uses Quickshell's toplevel protocol and only pauses the affected output; the wallpaper keeps its existing bottom layer, empty input region, and no keyboard focus.

## Settings

Edit `~/walls/Velina.premiumwall.json`; active Velina components watch the file and apply settings without restarting the panel.

| Setting | Default | Effect |
| --- | --- | --- |
| `openingEnabled` | `true` | Allow the opening on first selection in each graphical session. Turn this off before startup to go directly to the showcase. |
| `startupAudio` | `true` | Enable the original opening cue. Sound is limited to one output per session. |
| `loop` | `true` | Repeat the showcase indefinitely. When false, hold its last frame after one play. |
| `effectsQuality` | `"high"` | `off`, `low` (3 leaf motes), or `high` (7). |
| `pauseWhenFullscreen` | `true` | Pause while a focused fullscreen application occupies that output. |
| `fit` | `"cover"` | Uniform fullscreen crop; `contain` preserves the whole image with a pale background around it. Neither stretches the video. |

Disabling opening during playback transitions to the showcase; enabling it after a component has already initialized takes effect on the next session. Disabling audio mutes an opening immediately. The selected manifest is persisted through the existing `~/.cache/current-wallpaper` mechanism.

## Media and visual reconstruction

All wallpapers and prepared runtime assets are versioned in [dots-wallpapers](https://github.com/cfels/dots-wallpapers). The dotfiles submodule at `Configs/walls/walls` preserves the existing `~/walls` link; media remains under `~/walls/PremiumWalls/Velina/`. Fetch it with `git submodule update --init --recursive` from the dotfiles repository. The renderer stays in the dotfiles repository. No extraction tools or game install are needed to play the prepared assets.

- `opening.mp4`: byte-for-byte copy of `Velina-opening-HQ-with-sound.mp4`, 1920×1080, 60 fps, 501 frames / 8.35 seconds, H.264 High / YUV420P / BT.709 with stereo AAC at 48 kHz.
- `showcase.mp4`: 1920×1080, 60 fps, 320 frames / 5.333333 seconds, silent H.264 High / YUV420P / BT.709, rendered directly from PNG frames at CRF 10.
- `poster.png` and `opening-poster.png`: decoded first frames, protecting load/seek boundaries.
- `LeafPar00.png`: original extracted leaf particle sprite.
- `source.json`: source paths, hashes, and probed media metadata.

The previously exported standalone `Velina-showcase-HQ.mp4` uses a different background layout and character phase. The wallpaper continuation instead uses the opening renderer from 8.35 seconds onward, with its incremental physics warmed through the opening. This preserves the final composition and continues the character's phase. No video-to-video transcode is used to create it.

The character, title, gradients, gold corner ornaments, wind, pearls, flowers, and UI leaf entrance tracks are already baked into the clips. QML does not draw them again. `VelinaEffects` adds the omitted particle layer using the extracted leaf sprite. Its entrance begins at the original `LoopPar` activation time, 0.7666667 seconds. Its clock follows video positions and counts loop wraps, and freezes while paused. Particle trajectories are an approximation: the original Unity particle parameters/custom shader behavior were not recovered. The source previews also omit the gameplay nameplate and approximate some Unity masks/shaders; this implementation does not claim pixel-identical Unity rendering.

To regenerate the continuation using the extraction workspace (an offline preparation step only):

```bash
cd ~/Downloads/hoyo-files
python3 -m http.server 8877 --bind 127.0.0.1 --directory investigation/velina
# In another terminal, using the capture dependencies documented in that workspace:
bun investigation/velina/tools/render_preview.mjs /tmp/velina-continuation --continuation --lossless-master
```

Prepare a fresh output directory, then use it as `PremiumWalls/Velina` before selecting the manifest:

```bash
python3 ~/.config/hypr/scripts/premium-wallpaper-prepare.py \
  ~/Downloads/hoyo-files/investigation/velina \
  /tmp/velina-continuation \
  /tmp/velina-prepared-media
```

The preparation helper verifies resolution, frame rate, and audio presence; copies both videos without re-encoding; creates posters; and records hashes. It refuses to overwrite an existing destination. It never accesses installed game files.

## Checks and troubleshooting

```bash
cd ~/nixos-dots
python3 -B -m unittest discover -s tests -p 'test_*wallpaper.py' -v
python3 -B tests/velina_native_check.py /tmp/velina-native-check
python3 -B tests/velina_native_check.py /tmp/velina-native-timing --measure-only
qs -p ~/.config/quickshell/moxi/wallpaper/shell.qml ipc call wallpaper status
```

The synthetic playback scenario covers first startup without an empty reveal, a delayed audio device and captured non-silent audio through an isolated PulseAudio sink, synchronized audio ownership, real `EndOfMedia` handoff, repeated loops, fullscreen pause/resume, component destruction/recreation, and live loop/effect settings. Native checking additionally plays the real 1080p60 media through `WallpaperCanvas` in an isolated Xvfb desktop, captures frames, and measures frame delivery across three wraps. The capture pass can stall the scene graph during PNG readback; use `--measure-only` for frame-delivery measurements without capture overhead. The prepared clips completed three wraps with a measured maximum delivery gap of 18 ms in the software test. The native visual test deliberately uses software rendering with startup audio disabled; the synthetic scenario verifies audio separately without accessing host speakers. These isolated tests cannot verify audible host output or AMD acceleration. The live desktop was also checked: opening → transition → showcase, a loop wrap, and a wallpaper-only configuration reload without replaying the opening. AMD hardware decoding was confirmed by increasing `drm-engine-dec` counters on the wallpaper process. A complete logout/login was not performed; startup reservation behavior is covered by isolated tests with distinct compositor signatures.

`$XDG_RUNTIME_DIR/moxi-wallpaper/renderer.log` contains `PremiumWalls` state transitions and media errors. Run the manifest helper's `describe` command to diagnose missing/invalid assets. If a decoder fails, select another wallpaper and then reselect Velina; the session marker still prevents the opening audio from replaying.

`wallpaper-render.py` already selects Qt's FFmpeg backend and locates Qt Multimedia. Qt chooses hardware decoding automatically when supported. No software-only flag is added to the desktop renderer. For diagnostics, launch the renderer with `QT_LOGGING_RULES='qt.multimedia.*=true'`; [Qt documents hardware decoder controls](https://doc.qt.io/qt-6/advanced-ffmpeg-configuration.html) for driver troubleshooting. The frame-holding behavior uses the documented [VideoOutput end-of-stream policy](https://doc.qt.io/qt-6/qml-qtmultimedia-videooutput.html#endOfStreamPolicy-prop).
