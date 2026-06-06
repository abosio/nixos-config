# modules/nixos/users.nix
{ pkgs, ... }:

{
  users.users.abosio = {
    isNormalUser = true;
    description = "Anthony Bosio";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.zsh;
  };
}
