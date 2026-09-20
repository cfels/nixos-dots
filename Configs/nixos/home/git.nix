{ config, pkgs, lib, ... }: {
  programs.git = {
    enable = true;
    signing.key = "FF3392BF";
    signing.signByDefault = true;
    settings = {
      user.name = "cfels";
      user.email = "moxiix@proton.me";
      init.defaultBranch = "main";
      core.editor = "nvim";
    };
  };

  programs.lazygit = {
    enable = true;
  };
}
