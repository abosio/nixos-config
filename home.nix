
{ pkgs, ... }:

{
  home.username = "abosio";
  home.homeDirectory = "/home/abosio";
  home.stateVersion = "25.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Packages installed for your user
  home.packages = [
    pkgs.age
    pkgs.fira-code
    pkgs.sops
    pkgs.ssh-to-age
  ];

  programs.kitty = {
    enable = true;
    font = {
      name = "Fira Code";
      size = 14;
    };
    theme = "Solarized Dark";
  };

  # Some services
  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 1800;
    enableSshSupport = true;
  };

}
