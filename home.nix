
{ pkgs, ... }:

{
  imports = [
    ./zsh.nix
  ];

  home.username = "abosio";
  home.homeDirectory = "/home/abosio";
  home.stateVersion = "25.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Packages installed for your user
  home.packages = [
    pkgs.age
    pkgs.bat
    pkgs.cliphist
    pkgs.docker
    pkgs.eza
    pkgs.fira-code
    pkgs.git
    pkgs.joplin-desktop
    pkgs.libreoffice
    pkgs.logseq
    pkgs.signal-desktop
    pkgs.slack
    pkgs.sops
    pkgs.ssh-to-age
    pkgs.syncthing
    pkgs.tigervnc
    pkgs.vlc
    pkgs.vscode
    pkgs.wl-clipboard
    pkgs.zoom-us
    pkgs.zoxide
  ];

  programs.kitty = {
    enable = true;
    shellIntegration.enableZshIntegration = true;
    font = {
      name = "Fira Code";
      size = 14;
    };
    themeFile = "Nord";
  };

  # Some services
  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 1800;
    enableSshSupport = true;
  };

}
