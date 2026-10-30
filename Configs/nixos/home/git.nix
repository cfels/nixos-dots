{ config, pkgs, lib, ... }: {
  programs.git = {
    enable = true;
    signing.key = "19EC434750D0C5FA";
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
