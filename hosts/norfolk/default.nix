# hosts/norfolk/default.nix
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/common.nix
    ../../modules/nixos/printing.nix
    ../../modules/nixos/syncthing.nix
    ../../modules/nixos/users.nix       # shared abosio account
  ];

  networking.hostName = "norfolk";

  # Boot — confirmed UEFI.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # --- GPU (GTX 1070 Ti / Pascal) ---
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = true;
    open = false;                                   # Pascal: closed modules only
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # --- Desktop (MATE on X11 + LightDM) ---
  # lightdm and mate are still natively xserver-namespaced in 26.05 (unlike
  # gnome/gdm), so these are the current option paths and do not warn.
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.mate.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # WiFi: in-tree rtl8192ce needs redistributable firmware.
  hardware.enableRedistributableFirmware = true;
  # If rtlwifi power-save flakiness recurs:
  #   boot.extraModprobeConfig = "options rtl8192ce ips=0 fwlps=0";

  hardware.cpu.amd.updateMicrocode = true;

  # --- Users: pin IDs to the preserved /home HDD ---
  users.groups.abosio.gid = 1000;
  users.users.abosio = { uid = 1000; group = "abosio"; };  # augments shared users.nix

  users.groups.jbosio.gid = 1001;
  users.users.jbosio = {
    isNormalUser = true;
    uid = 1001;
    group = "jbosio";
    description = "Jayme Bosio";
    extraGroups = [ "networkmanager" ];   # non-admin: no wheel
    shell = pkgs.zsh;
  };

  system.stateVersion = "26.05";   # fresh install on this machine
}
