{ config, pkgs, lib, ... }: {
  programs.git = {
    enable = true;
    signing.key = "~/.ssh/id_ed25519.pub";
    signing.signByDefault = true;
    settings = {
      user.name = "cfels";
      user.email = "moxiix@proton.me";
      init.defaultBranch = "main";
      core.editor = "nvim";
      gpg.format = "ssh";
    };
  };

  programs.lazygit = {
    enable = true;
  };
}
