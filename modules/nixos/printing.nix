# modules/nixos/printing.nix
{ pkgs, ... }:

{
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
}
