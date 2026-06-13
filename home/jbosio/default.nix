# home/jbosio/default.nix
{ pkgs, ... }:
{
  imports = [
    ../shared/kitty.nix
    ../shared/zsh.nix          # framework only (no aliases)
  ];

  home.username = "jbosio";
  home.homeDirectory = "/home/jbosio";
  home.stateVersion = "26.05"; # her own, new user

  programs.home-manager.enable = true;
  programs.firefox.enable = true;

  home.packages = with pkgs; [
    blender                    # norfolk runs it; jbosio exists only on norfolk
  ];
}
