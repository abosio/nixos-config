# Printer Discovery and Configuration Guide

This document explains the commands used to discover, identify, and configure the Brother HL-2170W printer on NixOS.

## Table of Contents
1. [Network Printer Discovery](#network-printer-discovery)
2. [Hostname Resolution Testing](#hostname-resolution-testing)
3. [Finding Available Printer Drivers](#finding-available-printer-drivers)
4. [Configuration Process](#configuration-process)

---

## Network Printer Discovery

### Command: `avahi-browse`

```bash
avahi-browse -a -t -r
```

**Purpose:** Discover devices on the local network that advertise services via mDNS/Avahi (like printers, file servers, etc.)

**Flags:**
- `-a` - Browse for all service types
- `-t` - Terminate after dumping a complete list (don't continue monitoring)
- `-r` - Resolve service information (get detailed info like hostnames, IPs, and TXT records)

**Why we used it:** To discover if the printer broadcasts its presence on the network and to find its mDNS hostname.

**Output (filtered for Brother printer):**
```bash
avahi-browse -a -t -r | grep -i brother
```

This revealed:
- Service name: `Brother HL-2170W series`
- Hostname: `BRN001BA92DE10D.local`
- Services advertised: `_ipp._tcp`, `_pdl-datastream._tcp`, `_printer._tcp`, `_http._tcp`
- The printer supports IPP (Internet Printing Protocol)

**Key finding:** The hostname `BRN001BA92DE10D.local` is based on the printer's MAC address (BRN + MAC address), which means it won't change even if the DHCP IP address changes.

---

## Hostname Resolution Testing

### Command: `ping`

```bash
ping -c 2 BRN001BA92DE10D.local
```

**Purpose:** Verify that the mDNS hostname resolves correctly and the printer is reachable on the network.

**Flags:**
- `-c 2` - Send only 2 ping packets (count = 2), then stop

**Why we used it:** To confirm that:
1. The mDNS hostname resolution works (thanks to Avahi being configured with `nssmdns4`)
2. The printer is online and reachable
3. The hostname resolves to the expected IP address (192.168.50.22)

**Output:**
```
PING BRN001BA92DE10D.local (192.168.50.22) 56(84) bytes of data.
64 bytes from BRN001BA92DE10D.local (192.168.50.22): icmp_seq=1 ttl=255 time=5.22 ms
64 bytes from BRN001BA92DE10D.local (192.168.50.22): icmp_seq=2 ttl=255 time=68.9 ms
```

**Result:** Hostname resolves correctly to 192.168.50.22 and printer responds to pings.

---

## Finding Available Printer Drivers

### Command: `lpinfo -m`

```bash
lpinfo -m
```

**Purpose:** List all available printer models and their PPD (PostScript Printer Description) drivers that CUPS knows about.

**Flags:**
- `-m` - List available models/drivers

**Why we used it:** To find which printer driver to use in the NixOS configuration. We needed to find either an exact match for HL-2170W or a compatible driver from the same series.

### Searching for specific models:

**Search for exact model (HL-2170):**
```bash
lpinfo -m | grep -i "2170"
```

**Breakdown:**
1. `lpinfo -m` - List all printer models
2. `|` - Pipe the output to the next command
3. `grep -i "2170"` - Search for lines containing "2170"
   - `-i` - Case-insensitive search

**Result:** No exact HL-2170 or HL-2170W driver found.

**Search for Brother HL-2 series printers:**
```bash
lpinfo -m | grep -i "brother" | grep -i "hl-2" | head -20
```

**Breakdown:**
1. `lpinfo -m` - List all printer models
2. `|` - Pipe to next command
3. `grep -i "brother"` - Filter for lines containing "brother" (case-insensitive)
4. `|` - Pipe to next command
5. `grep -i "hl-2"` - Further filter for "hl-2" (case-insensitive)
6. `|` - Pipe to next command
7. `head -20` - Show only the first 20 results

**Why we chained greps:** To narrow down results progressively:
- First grep: Get all Brother printers
- Second grep: Get only HL-2xxx series from Brother printers
- head: Limit output to manageable size

**Output (partial):**
```
drv:///brlaser.drv/br2030.ppd Brother HL-2030 series, using Owl-Maintain/brlaser v6.2.7
drv:///brlaser.drv/br2130.ppd Brother HL-2130 series, using Owl-Maintain/brlaser v6.2.7
drv:///brlaser.drv/br2140.ppd Brother HL-2140 series, using Owl-Maintain/brlaser v6.2.7
drv:///brlaser.drv/br2220.ppd Brother HL-2220 series, using Owl-Maintain/brlaser v6.2.7
drv:///brlaser.drv/br2230.ppd Brother HL-2230 series, using Owl-Maintain/brlaser v6.2.7
drv:///brlaser.drv/br2240.ppd Brother HL-2240 series, using Owl-Maintain/brlaser v6.2.7
drv:///brlaser.drv/br2240d.ppd Brother HL-2240D series, using Owl-Maintain/brlaser v6.2.7
drv:///brlaser.drv/br2270d.ppd Brother HL-2270DW series, using Owl-Maintain/brlaser v6.2.7
```

**Key finding:** The HL-2140 driver (`drv:///brlaser.drv/br2140.ppd`) is the closest match to the HL-2170W, as they're from the same generation and series.

**Search for Brother generic drivers:**
```bash
lpinfo -m | grep -i "brother" | grep -v "gutenprint" | head -30
```

**Breakdown:**
1. `lpinfo -m` - List all printer models
2. `|` - Pipe to next command
3. `grep -i "brother"` - Filter for Brother printers (case-insensitive)
4. `|` - Pipe to next command
5. `grep -v "gutenprint"` - Exclude gutenprint drivers
   - `-v` - Invert match (show lines that DON'T match)
6. `|` - Pipe to next command
7. `head -30` - Show first 30 results

**Why we excluded gutenprint:** We wanted to focus on Brother-specific drivers (brlaser and brgenml1) rather than the generic gutenprint drivers, as manufacturer drivers typically provide better compatibility.

**Output (partial):**
```
brother-BrGenML1-cups-en.ppd Brother BrGenML1 for CUPS
drv:///brlaser.drv/br2140.ppd Brother HL-2140 series, using Owl-Maintain/brlaser v6.2.7
```

---

## Configuration Process

### Final Working Configuration

Based on the discovery process, we configured the printer in [configuration.nix](../configuration.nix):

```nix
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
```

### Configuration Decisions Explained

1. **`services.printing.enable = true`**
   - Enables CUPS (Common Unix Printing System)

2. **`services.printing.drivers`**
   - `brlaser` - Brother laser printer driver (used for HL-2140 PPD)
   - `brgenml1lpr` and `brgenml1cupswrapper` - Brother generic drivers (backup options)
   - Other drivers included for potential future printers

3. **`services.avahi.publish.enable = true`**
   - Allows this machine to advertise services on the network
   - Needed for printer sharing (if desired in the future)

4. **`hardware.printers.ensurePrinters`**
   - Declarative printer configuration (printer is configured automatically on rebuild)
   - Note: This is `hardware.printers`, NOT `services.printing.ensurePrinters` (which doesn't exist in NixOS 25.05)

5. **`deviceUri = "ipp://BRN001BA92DE10D.local/ipp/port1"`**
   - Uses hostname instead of IP address (survives DHCP changes)
   - Protocol: IPP (Internet Printing Protocol)
   - Path: `/ipp/port1` (standard IPP endpoint discovered via Avahi)

6. **`model = "drv:///brlaser.drv/br2140.ppd"`**
   - Uses HL-2140 driver (closest available match to HL-2170W)
   - Format: `drv:///` indicates a driver-provided PPD file
   - Source: `brlaser.drv` driver package
   - File: `br2140.ppd` PPD file for HL-2140 series

7. **`ppdOptions = { PageSize = "Letter"; }`**
   - Sets default paper size to Letter (US standard)
   - Other common option: "A4" (international standard)

### Troubleshooting Notes

**Attempts that failed:**

1. **`model = "everywhere"`** - IPP Everywhere (driverless printing)
   - Error: "Printer does not support required IPP attributes or document formats"
   - Reason: HL-2170W is too old to fully support IPP Everywhere standard

2. **`model = "drv:///brlaser.drv/br2170w.ppd"`** - Exact model match attempt
   - Error: "cups-driverd failed to get PPD file"
   - Reason: No HL-2170W-specific driver exists in the brlaser package

3. **`services.printing.ensurePrinters`** - Wrong configuration option
   - Error: "The option `services.printing.ensurePrinters' does not exist"
   - Reason: The correct option is `hardware.printers.ensurePrinters` in NixOS

### Applying the Configuration

```bash
sudo nixos-rebuild switch --flake .
```

**What this does:**
1. Builds the new system configuration
2. Activates it immediately (makes it the current running system)
3. Sets it as the default for next boot

**The `--flake .` flag:**
- `.` - Use the flake in the current directory
- Expands to `/home/abosio/nixos-config` when run from that directory

---

## Verification Commands

After configuration, verify the printer is set up:

```bash
# List configured printers
lpstat -p -d

# Check printer status
lpstat -t

# Print a test page
lp -d Brother_HL-2170W /usr/share/cups/data/testprint

# Check CUPS web interface (in browser)
# http://localhost:631
```

---

## Additional Resources

- NixOS Printing Wiki: https://wiki.nixos.org/wiki/Printing
- CUPS Documentation: https://www.cups.org/doc/
- Avahi/mDNS: https://www.avahi.org/
- Brother brlaser driver: https://github.com/pdewacht/brlaser
