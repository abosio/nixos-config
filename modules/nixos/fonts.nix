# modules/nixos/fonts.nix
{ pkgs, ... }:

{
  fonts = {
    packages = with pkgs; [
      fira-code
    ];
    fontconfig.enable = true;
    fontDir.enable = true;
  };
}
