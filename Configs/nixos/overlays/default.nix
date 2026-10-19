{ vice-clipper }:
final: prev: {
  vice-clipper = vice-clipper prev;

  droidcam = prev.droidcam.overrideAttrs (old: {
    postPatch = old.postPatch + ''
      substituteInPlace src/decoder_v4l2.c \
        --replace-fail '        if (xioctl(fd, VIDIOC_S_FMT, &vid_format) >= 0) {' \
          '        set_control_i(fd, "keep_format", 0);
              if (xioctl(fd, VIDIOC_S_FMT, &vid_format) >= 0) {'
    '';
  });

  imagemagick-native = prev.imagemagick.overrideAttrs (old: {
    configureFlags = map (
      flag: if flag == "--with-gcc-arch=generic" then "--without-gcc-arch" else flag
    ) (old.configureFlags or [ ]);
    env = (old.env or { }) // {
      NIX_CFLAGS_COMPILE = (old.env.NIX_CFLAGS_COMPILE or "") + " -O3 -march=znver4";
    };
  });

  p7zip-native = prev.p7zip.overrideAttrs (old: {
    preBuild = (old.preBuild or "") + ''
      makeFlagsArray+=("OPTFLAGS=-O3 -march=znver4 -s")
    '';
  });

  ffmpeg-native = prev.ffmpeg.overrideAttrs (old: {
    configureFlags = (old.configureFlags or [ ]) ++ [
      "--cpu=znver4"
      "--optflags=-O3"
    ];
  });

  zstd-native = prev.zstd.overrideAttrs (old: {
    env = (old.env or { }) // {
      NIX_CFLAGS_COMPILE = (old.env.NIX_CFLAGS_COMPILE or "") + " -O3 -march=znver4";
    };
  });

  xz-native = prev.xz.overrideAttrs (old: {
    env = (old.env or { }) // {
      NIX_CFLAGS_COMPILE = (old.env.NIX_CFLAGS_COMPILE or "") + " -O3 -march=znver4";
    };
  });
}
