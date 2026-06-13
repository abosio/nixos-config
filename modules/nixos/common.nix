# modules/nixos/common.nix
# Base settings every machine in the fleet gets.
{ inputs, pkgs, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "electron-39.8.10" # required by logseq, pending upstream update
  ];

  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = false;

  networking.networkmanager.enable = true;
  networking.extraHosts = ''
    167.71.175.50   git.abosio.com
  '';

  services.avahi = {
    enable = true;
    nssmdns4 = true; # Enable mDNS resolution for .local domains
  };

  services.openssh.enable = true;

  time.timeZone = "America/New_York";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  programs.zsh.enable = true;
  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    vim
  ];

  # Add Caddy internal CA certificate for *.abosio-cloud.com
  security.pki.certificateFiles = [
    "${inputs.nixos-secrets}/caddy-root-ca.crt"
  ];

  # Tailscale (every host).
  services.tailscale.enable = true;

  # 1Password CLI + GUI (every host; abosio owns the polkit policy).
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "abosio" ];
  };

  # Fonts (every host).
  fonts = {
    packages = with pkgs; [ fira-code ];
    fontconfig.enable = true;
    fontDir.enable = true;
  };
}
