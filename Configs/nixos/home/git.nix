{ config, pkgs, lib, ... }: {
  programs.git = {
    enable = true;
    signing.key = "FE945522C38C78EE";
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
