# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./modules/nixos/common.nix
      ./modules/nixos/fonts.nix
      ./modules/nixos/desktop-gnome.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "logan"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Configure AMD GPU drivers for hybrid graphics (RX 7600M + Radeon 680M)
  services.xserver.videoDrivers = [ "amdgpu" ];

  # Enable hardware acceleration for AMD GPUs
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = with pkgs; [
    gutenprint        # High-quality drivers for Canon, Epson, Lexmark, Sony, Olympus
    hplip             # HP printers
    brlaser           # Brother laser printers
    brgenml1lpr       # Brother generic driver
    brgenml1cupswrapper
  ];
  # Enable printer discovery via Avahi
  services.avahi.publish.enable = true;
  services.avahi.publish.userServices = true;

  # Configure Brother HL-2170W printer
  hardware.printers.ensurePrinters = [{
    name = "Brother_HL-2170W";
    location = "Home";
    deviceUri = "ipp://BRN001BA92DE10D.local/ipp/port1";
    model = "drv:///brlaser.drv/br2140.ppd";
    description = "Brother HL-2170W";
    ppdOptions = {
      PageSize = "Letter";
    };
  }];

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don’t forget to set a password with ‘passwd’.
  users.users.abosio = {
    isNormalUser = true;
    description = "Anthony Bosio";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.zsh;
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    # Certain features, including CLI integration and system authentication support,
    # require enabling PolKit integration on some desktop environments (e.g. Plasma).
    polkitPolicyOwners = [ "abosio" ];
  };
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  services.tailscale.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Setup syncthing
  services.syncthing = {
    enable = true;
    user = "abosio";
    openDefaultPorts = true; # Open ports in the firewall for Syncthing
    dataDir = "/home/abosio/.local/share/syncthing";
    configDir = "/home/abosio/.config/syncthing";
    settings = {
      devices = import "${inputs.nixos-secrets}/syncthing-devices.nix";
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?


  fileSystems."/mnt/pi" = {
    device = "raspberrypi5.local:/home/abosio";
    fsType = "nfs";
    options = [ "x-systemd.automount" "noauto" "_netdev" ];
  };

}
