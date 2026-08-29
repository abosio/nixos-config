# hosts/logan/default.nix
{ inputs, pkgs, ... }:

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

  # --- Kernel pin (temporary) ---
  # 6.18.34-6.18.37 regressed amdgpu s2idle resume on the discrete RX 7600M
  # (dGPU 0000:03:00.0: "resume of IP block <smu> failed -22", PCIe AER recovery
  # fail), stalling the compositor for ~30-60s after wake so the mouse appears
  # dead. 6.18.33 ran 59 clean suspend cycles. Pinned to 6.18.33 via the
  # nixpkgs-kernel flake input; remove this and the input once a fixed 6.18.y
  # reaches nixos-26.05. Diagnosed 2026-07-03.
  boot.kernelPackages = (import inputs.nixpkgs-kernel {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  }).linuxPackages;

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

  environment.systemPackages = [ pkgs.gnomeExtensions.tailscale-qs ];

  # --- Super key fix ---
  # The TUF Gaming A16 FA617NT's firmware routes the physical Super key through
  # the "Asus WMI hotkeys" virtual device as unmapped scancode 0x4f (KEY_UNKNOWN)
  # instead of KEY_LEFTMETA on the real keyboard, so GNOME never sees a Super
  # press (overlay-key, Super+Left/Right tiling, etc. silently do nothing).
  # systemd's stock 60-keyboard.hwdb has no entry for this model; this adds one.
  # Diagnosed 2026-08-29 via `libinput debug-events` + `evtest`.
  services.udev.extraHwdb = ''
    evdev:name:Asus WMI hotkeys:dmi:bvn*:bvr*:bd*:svnASUSTeKCOMPUTERINC.:pnASUSTUFGamingA16FA617NT_FA617NT:*
     KEYBOARD_KEY_4f=leftmeta
  '';

  # First-install release marker for THIS machine (per-host, never bumped lightly).
  system.stateVersion = "25.05";
}
