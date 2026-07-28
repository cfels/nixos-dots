{ config, pkgs, lib, ... }: {
  programs.git = {
    enable = true;
    userName = "cfels";
    userEmail = "moxiix@proton.me";
    signing.key = "24A060859F7F1C76";
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
