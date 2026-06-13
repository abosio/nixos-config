# hosts/norfolk/hardware-configuration.nix
# TEMPORARY STUB for flake evaluation on Logan only.
# REPLACE on the machine in Phase 2 with:
#   sudo nixos-generate-config --show-hardware-config > hosts/norfolk/hardware-configuration.nix
# The real file provides the actual root/ESP UUIDs AND the preserved /home mount.
{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Placeholder root + boot so the config evaluates/builds on Logan. Real values
  # come from nixos-generate-config on norfolk. The /home mount (preserved HDD,
  # UUID 26b3c25e-267a-4717-a091-f77f050b01e3) is added by the generated file in
  # Phase 2 and is intentionally NOT declared here.
  boot.loader.grub.devices = lib.mkDefault [ "nodev" ];
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
    fsType = "ext4";
  };
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
