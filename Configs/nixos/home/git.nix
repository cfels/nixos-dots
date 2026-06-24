{ config, pkgs, lib, ... }: {
  programs.git = {
    enable = true;
    userName = "cfels";
    userEmail = "moxiix@proton.me";
    extraConfig = {
      init.defaultBranch = "main";
    };
  };

  programs.lazygit = {
    enable = true;
  };
}