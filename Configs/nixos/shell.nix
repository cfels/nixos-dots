# Nix shell for building LineageOS.
#
# Usage:
#   nix-shell              # enter the FHS build environment
#   nix-shell --pure       # recommended: ignore host packages/env
#
# You can pick a different LineageOS version/Java with:
#   nix-shell --arg lineageVersion 23

{ pkgs ? import <nixpkgs> { }
, lineageVersion ? 21
}:

let
  # Host JDK used by repo/Soong.  LOS itself ships a prebuilt JDK in-tree for
  # most of the build, but the wrapper still needs a compatible host JDK.
  jdkPackage =
    if lineageVersion >= 23 then pkgs.jdk17
    else if lineageVersion >= 18 then pkgs.jdk11
    else pkgs.jdk8;

  jdkHome = jdkPackage.home;

  branch = "lineage-${toString lineageVersion}.0";

  # Older nixpkgs calls this buildFHSUserEnv; newer nixpkgs calls it buildFHSEnv.
  buildFHSEnv = pkgs.buildFHSEnv or pkgs.buildFHSUserEnv;

  fhsEnv = buildFHSEnv {
    name = "lineageos-${toString lineageVersion}-build-env";

    # Some host tools and older prebuilts are 32-bit.
    multiArch = true;

    # Tools and libraries exposed in the FHS environment.
    targetPkgs = pkgs: with pkgs; [
      # LineageOS/AOSP host build tools
      bc
      binutils
      bison
      ccache
      curl
      flex
      gcc
      gnumake
      gnupg
      gperf
      imagemagick
      lz4
      lzop
      m4
      nettools
      openssl.dev
      perl
      pngcrush
      procps
      python3
      rsync
      schedtool
      SDL
      squashfsTools
      unzip
      util-linux
      wget
      xml2
      zip

      # Version control
      git
      git-lfs
      git-repo

      # Java / Android
      jdkPackage
      android-tools

      # Libraries that prebuilt binaries/kernels often link against
      freetype
      fontconfig
      libxcrypt-legacy
      yaml-cpp
      elfutils
      libxml2
      libxslt

      # Personal shell environment (fish + bash + your tools)
      bash
      fish
      starship
      fastfetch
      fnm
      zoxide
      fzf
      eza
      helix
    ];

    # 32-bit libraries needed by some host tools and older prebuilts.
    multiPkgs = pkgs: with pkgs; [
      zlib
      ncurses5
      readline
      libcxx
      gcc.cc
      iconv
      iconv.dev
    ];

    runScript = "fish";

    profile = ''
      export ALLOW_NINJA_ENV=true
      export USE_CCACHE=1
      export CCACHE_COMPRESS=1
      export CCACHE_MAXSIZE=50G
      export CCACHE_EXEC=/usr/bin/ccache
      export CCACHE_DIR="''${CCACHE_DIR:-$HOME/.ccache}"
      export JAVA_HOME=${jdkHome}
      export ANDROID_JAVA_HOME=${jdkHome}
      export TMPDIR=/tmp
      export LC_ALL=C.UTF-8
      export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib:${pkgs.ncurses5}/lib

      # Android builds open a huge number of files.
      ulimit -n 65536 2>/dev/null || ulimit -n 4096 2>/dev/null || true

      export SHELL=/usr/bin/fish

      cat <<BANNER

=== LineageOS ${toString lineageVersion} build environment ===
  shell:        fish (use bash for envsetup.sh)
  JDK:          ${jdkHome}
  repo branch:  ${branch}
  CCACHE_DIR:   $CCACHE_DIR

Quick start (inside this shell):
  cd <your-source-tree>
  repo init -u https://github.com/LineageOS/android.git -b ${branch} --git-lfs
  repo sync

  bash                      # envsetup.sh only works in bash
  source build/envsetup.sh
  lunch lineage_<device>-userdebug
  mka bacon
=====================================
BANNER
    '';
  };
in
fhsEnv.env
