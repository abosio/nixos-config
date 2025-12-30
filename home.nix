
{ pkgs, ... }:

{
  imports = [
    ./kitty.nix
    ./packages.nix
    ./zsh.nix
  ];

  home.username = "abosio";
  home.homeDirectory = "/home/abosio";
  home.stateVersion = "25.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Setup Mozilla
  programs.firefox.enable = true;
  programs.thunderbird = {
    enable = true;
    profiles = {
      default = {
        isDefault = true;
      };
    };
  };

  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";
    matchBlocks = {
      "raspberrypi5 raspberrypi5.local" = {
        forwardAgent = true;
      };
    };
    extraConfig = ''
      Host *
        SetEnv TERM=xterm-256color
    '';
  };


  # Some services
  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 1800;
    enableSshSupport = true;
    pinentryPackage = pkgs.pinentry-gnome3;
  };

  dconf.settings = {
    "org/gnome/desktop/input-sources" = {
      xkb-options = ["ctrl:nocaps"];
    };
  };

}
