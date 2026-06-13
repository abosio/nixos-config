# hosts/logan/default.nix
{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/common.nix
    ../../modules/nixos/desktop-gnome.nix
    ../../modules/nixos/printing.nix
    ../../modules/nixos/users.nix
    ../../modules/nixos/amdgpu.nix
    ../../modules/nixos/syncthing.nix
  ];

  networking.hostName = "logan";

  # Bootloader (Logan is UEFI / systemd-boot).
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Logan-specific NFS mount to the Raspberry Pi 5.
  fileSystems."/mnt/pi" = {
    device = "raspberrypi5.local:/home/abosio";
    fsType = "nfs";
    options = [ "x-systemd.automount" "noauto" "_netdev" ];
  };

  # First-install release marker for THIS machine (per-host, never bumped lightly).
  system.stateVersion = "25.05";
}
