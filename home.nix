
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

  # Some services
  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 1800;
    enableSshSupport = true;
  };

}
