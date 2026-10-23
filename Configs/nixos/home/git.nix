{ config, pkgs, lib, ... }: {
  programs.git = {
    enable = true;
    signing.key = "CCDFD72CE09C86DC";
    signing.signByDefault = true;
    settings = {
      user.name = "cfels";
      user.email = "moxiix@proton.me";
      init.defaultBranch = "main";
      core.editor = "nvim";
      color.ui = "auto";
    };
  };

  programs.lazygit = {
    enable = true;
  };
}
