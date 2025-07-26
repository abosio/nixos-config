
{ pkgs, ... }:

{
  home.username = "abosio";
  home.homeDirectory = "/home/abosio";
  home.stateVersion = "25.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Packages installed for your user
  home.packages = [
    phgs.fira-code  
  ];

  # The starship prompt is a good first package to install.
  #programs.starship.enable = true;
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
