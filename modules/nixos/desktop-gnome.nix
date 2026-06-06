# modules/nixos/desktop-gnome.nix
{ ... }:

{
  services.xserver.enable = true;

  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  programs.dconf = {
    enable = true;
    profiles.user.databases = [{
      settings = {
        "org/gnome/terminal/legacy/profiles:/:default" = {
          font = "Fira Code 14";
          use-system-font = false;
        };
      };
    }];
  };
}
