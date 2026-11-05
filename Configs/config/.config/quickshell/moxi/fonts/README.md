# Moxi Trust

One static ExtraBold (800) family for Moxi, with Momotrust's original Latin
design and multilingual glyphs adapted from the three existing Noto sources.
Quickshell loads **MoxiTrust-ExtraBold.ttf** once through `components/Fonts.qml`.
The original four TTFs are build inputs recovered temporarily from pinned Git
history. They are no longer shipped or installed alongside the merged family.

## What changed

- All 469 original Momotrust glyphs remain in their original order, including
  unencoded alternates. Their outlines, advances, hint programs, kerning and
  tested Latin shaping are unchanged. Momotrust's naturally heavy Regular
  outlines are preserved rather than artificially emboldened.
- Added glyphs use the existing 800-weight Noto sources. Cyrillic is scaled
  1.025 horizontally and 1.05 vertically, with slightly tighter side bearings.
  Its cap height now matches Momotrust's 750-unit capitals closely.
- Japanese and Korean glyphs use a 0.94 scale and a 24-unit vertical offset.
  Their optical centers align with Momotrust while dense characters retain
  enough room to remain readable.
- Conservative quadratic fillets soften straight-line corners in added
  glyphs. Existing curves are retained. Cuts are limited to 12% of either
  adjoining edge; acute joins and very short strokes are left alone.
- The original GSUB/GPOS features are merged, feature-name IDs are remapped,
  and shared Momotrust combining marks receive attachment lookups for added
  bases. Modern decomposed Hangul composes correctly.
- Japanese is the default for shared Han characters. The 607 differing
  Korean forms remain available through OpenType `locl` with Korean language
  selection (`ko`/`KOR`). Han text alone cannot reliably identify its language.
- The merged family contains the complete union of the sources: **31,449
  Unicode code points**, including all modern Hangul syllables, Hiragana,
  Katakana and the Cyrillic block. Characters absent from every source are
  not invented; rare unsupported characters still need another font.

This is automated optical harmonization, not a hand-drawn Japanese/Korean
Momotrust redesign. Noto's underlying character construction remains visible,
especially in complex Kanji and Hangul. Aggressive rounding or thickening
would close counters and damage legibility, so those changes are deliberately
limited. Added outlines are unhinted; the original Momotrust hints remain.

## Files and integration

- `MoxiTrust-ExtraBold.ttf`: complete native font, approximately 12.6 MiB.
- `MoxiTrust-ExtraBold.woff2`: the same complete font, approximately 3.4 MiB;
  lossless compressed outlines and shaping tables, suitable for web use.
- `moxi-trust.css`: one `@font-face`, family `Moxi Trust`, weight `800`.
  The full CJK/Hangul coverage is why the web file is larger than a Latin font.
- `MoxiTrust-ExtraBold.json`: reproducible source/output hashes, coverage,
  transformation profiles and layout-feature inventory.
- `scripts/fonts/sources.json`: original source hashes and their exact Git
  revision, kept with the build tools rather than the runtime assets.
- `OFL.txt`: source credits, reserved-name notice and SIL OFL 1.1 license.

All Quickshell text components share the new family, including the launcher,
clipboard, notifications and reload popup. Lyrics retain their existing color
animation, wrapping and escaping without per-script weight tags. Emoji and
dedicated icon faces keep their separate roles.

The existing Stow package installs the native font and its license through
`Configs/local/.local/share/fonts/MoxiTrust/`. The obsolete Momotrust install
link and its fontconfig fallback rule have been removed. Hyprlock and its
Matugen template request `Moxi Trust`. No NixOS rebuild or privileged font
installation is needed for Quickshell's
bundled font. A normal Stow update installs it for other desktop applications.

## Rebuild and test

From the repository root, use the project's pinned nixpkgs:

```sh
nix-shell scripts/fonts/shell.nix --run 'python3 scripts/fonts/build.py'
nix-shell scripts/fonts/shell.nix --run 'PYTHONPATH=tests python3 -B -m unittest test_fonts -v'
```

Builds and source-comparison tests recover the original fonts into a temporary
directory using `git show` at the revision recorded in `scripts/fonts/sources.json`.
The files are verified against their original SHA-256 hashes and removed when
the command finishes. No source fonts are reinstalled, and no network fetch
runs automatically.

For a source archive or shallow checkout without that Git history, provide the
four original TTFs in an external directory and pass `--sources /path/to/fonts`
to the builder. Source-comparison tests require the pinned Git history. The
shell itself only needs the merged TTF and works without Git metadata.

Or use Python with `fonttools[woff]` and `uharfbuzz` already available. These are
build/test tools, not runtime dependencies. `fontTools` 4.63.0 is recorded in
the build report. The builder verifies source hashes and em sizes, checks
source coverage and Momotrust geometry/hints, and publishes complete font
binaries with atomic replacements. Font timestamps
come from the original Momotrust source for repeatable output.

The tests additionally check cmap consistency, 800-weight metadata, original
Latin kerning and features, stress marks, JP/KR language forms, Hangul
composition, source notices, checksums and WOFF2 round trips. Existing isolated
Quickshell scenarios exercise the actual merged font in the bar and panel.

## License

All four provided fonts identify themselves as SIL OFL 1.1 in their embedded
license records. The derivative is also OFL 1.1, distributed as **Moxi Trust**,
with the original authors credited. It does not use the reserved name `Source`
as its font family and does not imply endorsement by the original designers.

Upstream license references:

- https://github.com/google/fonts/blob/main/ofl/momotrustdisplay/OFL.txt
- https://github.com/google/fonts/blob/main/ofl/notosans/OFL.txt
- https://github.com/google/fonts/blob/main/ofl/notosansjp/OFL.txt
- https://github.com/google/fonts/blob/main/ofl/notosanskr/OFL.txt
