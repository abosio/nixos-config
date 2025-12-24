{ pkgs, ... }:

{
  # Packages installed for your user
  home.packages = [
    pkgs.age
    pkgs.bat
    pkgs.calibre
    pkgs.claude-code
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
    pkgs.tor-browser
    pkgs.vivaldi
    pkgs.vlc
    pkgs.vscode
    pkgs.wl-clipboard
    pkgs.zoom-us
    pkgs.zoxide
  ];
}
