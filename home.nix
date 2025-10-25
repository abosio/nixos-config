
{ ... }:

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
  };

  dconf.settings = {
    "org/gnome/desktop/input-sources" = {
      xkb-options = ["ctrl:nocaps"];
    };
  };

}
