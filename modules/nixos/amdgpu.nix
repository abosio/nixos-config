# modules/nixos/amdgpu.nix
{ ... }:

{
  # Configure AMD GPU drivers for hybrid graphics (RX 7600M + Radeon 680M)
  services.xserver.videoDrivers = [ "amdgpu" ];

  # Enable hardware acceleration for AMD GPUs
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
}
