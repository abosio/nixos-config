
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

  # Setup firefox.
  programs.firefox.enable = true;

  # Some services
  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 1800;
    enableSshSupport = true;
  };

}
