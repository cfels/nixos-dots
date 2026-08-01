{ config, pkgs, lib, ... }: {
  programs.git = {
    enable = true;
    userName = "cfels";
    userEmail = "moxiix@proton.me";
    signing.key = "DBC91292";
    signing.signByDefault = true;
    extraConfig = {
      init.defaultBranch = "main";
      core.editor = "nvim";
    };
  };

  programs.lazygit = {
    enable = true;
  };
}
