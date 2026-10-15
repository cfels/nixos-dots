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
}
