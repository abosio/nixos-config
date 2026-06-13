# hosts/logan/default.nix
{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/common.nix
    ../../modules/nixos/printing.nix
    ../../modules/nixos/users.nix
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

  # --- GPU (inlined; was amdgpu.nix) ---
  # AMD GPU drivers for hybrid graphics (RX 7600M + Radeon 680M).
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  # --- Desktop (inlined; was desktop-gnome.nix) ---
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
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

  # First-install release marker for THIS machine (per-host, never bumped lightly).
  system.stateVersion = "25.05";
}
