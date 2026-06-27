{ config, pkgs, lib, ... }: {
  programs.git = {
    enable = true;
    userName = "cfels";
    userEmail = "moxiix@proton.me";
    signing.key = "85B2B66CE0A09BBF";
    signing.signByDefault = true;
    extraConfig = {
      init.defaultBranch = "main";
    };
  };

  programs.lazygit = {
    enable = true;
  };
}
