# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a flake-based NixOS configuration for multiple hosts: **logan** (AMD laptop, GNOME) and **norfolk** (NVIDIA desktop, MATE; second user `jbosio`). The configuration uses a three-layer architecture:
- **System Layer** - Per-host config in `hosts/<host>/` composing reusable `modules/nixos/` modules
- **User Layer** - Home-manager config in `home/<user>/`, sharing `home/shared/` modules
- **Secrets Layer** - External secrets via private nixos-secrets repository

## Key Commands

### Building and Deploying

```bash
# Rebuild and activate configuration
sudo nixos-rebuild switch --flake /home/abosio/nixos-config#logan

# Build without activating (test configuration)
sudo nixos-rebuild build --flake /home/abosio/nixos-config#logan

# Test configuration without building
sudo nixos-rebuild dry-run --flake /home/abosio/nixos-config#logan

# Boot into new generation (activate on next reboot)
sudo nixos-rebuild boot --flake /home/abosio/nixos-config#logan

# List recent generations (date, NixOS version, current marker)
nixos-rebuild list-generations
```

### Updating Dependencies

```bash
# Update all flake inputs
nix flake update

# Update specific input
nix flake update nixpkgs
nix flake update home-manager
```

## Architecture

### File Organization

```
flake.nix                      # Entry point - mkHost helper, declares logan + norfolk
├── hosts/
│   ├── logan/                 # AMD laptop; GNOME + amdgpu inline
│   │   ├── default.nix        # host settings + GPU/desktop inline + module imports
│   │   └── hardware-configuration.nix  # Auto-generated (DO NOT EDIT)
│   └── norfolk/               # NVIDIA desktop; MATE + nvidia inline; user jbosio
│       ├── default.nix        # host settings + GPU/desktop inline + users
│       └── hardware-configuration.nix  # Auto-generated (DO NOT EDIT)
├── modules/nixos/             # Shared system modules (imported by 2+ hosts)
│   ├── common.nix             # Base every machine gets (nix, locale, audio, ssh,
│   │                          #   networkmanager, avahi, zsh, nix-ld, unfree/insecure,
│   │                          #   vim, fonts, tailscale, 1Password, git.abosio.com, Caddy CA)
│   ├── printing.nix           # CUPS + drivers + avahi.publish + Brother printer
│   ├── syncthing.nix          # Host-aware syncthing (filters out own hostname)
│   └── users.nix              # Shared abosio system account
├── home/
│   ├── shared/                # Cross-user home-manager modules
│   │   ├── kitty.nix          # Terminal configuration
│   │   ├── packages.nix       # abosio's package base (obs on logan, blender on norfolk)
│   │   └── zsh.nix            # Shell framework (aliases live per-user)
│   ├── abosio/
│   │   └── default.nix        # abosio's config + aliases (host-conditional via osConfig)
│   └── jbosio/
│       └── default.nix        # Jayme's config (norfolk only)
└── docs/                      # Detailed documentation
    ├── README.md              # Documentation table of contents
    └── printer-setup.md       # Printer discovery and configuration guide
```

Single-host concerns (GPU, desktop environment) live inline in each host's
`default.nix`; `modules/nixos/` holds only what 2+ hosts share.

### Flake Inputs

- **nixpkgs** - NixOS packages (nixos-26.05)
- **nixpkgs-unstable** - Unstable channel for select packages (via `pkgs-unstable`)
- **home-manager** - User environment management (release-26.05)
- **sops-nix** - Secrets encryption (infrastructure ready, minimal current use)
- **nixos-secrets** - Private SSH repository
  - Currently used for Syncthing device configuration
  - Accessed via `inputs.nixos-secrets` in configuration files

### Configuration Layers

**System Configuration (`hosts/<host>/default.nix` + `modules/nixos/`):**
- Host file: hostname, bootloader, GPU + desktop (inline), `system.stateVersion`, module imports, host-specific users/mounts. logan = GNOME + amdgpu + `/mnt/pi`; norfolk = MATE + nvidia + `jbosio` account + preserved `/home`.
- `common.nix`: networking, audio (PipeWire), OpenSSH, Avahi mDNS, auto-upgrade, nix-ld, fonts, Tailscale, 1Password, Caddy CA
- Shared modules: CUPS + Brother printer (`printing.nix`), host-aware Syncthing (`syncthing.nix`), `abosio` account (`users.nix`)

**Home-Manager (`home/abosio/default.nix` + `home/shared/`):**
- Programs: Firefox, Thunderbird, SSH, GPG agent
- Keyboard remapping: CAPS LOCK to CTRL (via dconf)
- Shell aliases (abosio-specific) live in the user file; terminal/packages/zsh-framework are shared modules
- Per-host package divergence via `osConfig.networking.hostName` (e.g. obs-studio excluded on `norfolk`)

## Important Design Decisions

### Secrets Management

Secrets are stored in a separate private repository (nixos-secrets) accessed via SSH. The repository is accessed with `flake = false` (raw files, not a flake). To reference secrets:

```nix
imports = [ "${inputs.nixos-secrets}/syncthing-devices.nix" ];
```

### Network Configuration

**Avahi mDNS** is enabled with nssmdns4 for .local domain resolution. This is critical for:
- Syncthing device discovery
- NFS mount to Raspberry Pi 5 (via raspberrypi5.local)
- Printer discovery and hostname resolution (BRN001BA92DE10D.local)
- General LAN service discovery

Avahi publishing is also enabled (`services.avahi.publish`) to advertise services on the network.

### Hardware Configuration

The file [hosts/logan/hardware-configuration.nix](hosts/logan/hardware-configuration.nix) is auto-generated. Do not manually edit it. To regenerate:

```bash
sudo nixos-generate-config --show-hardware-config > hosts/logan/hardware-configuration.nix
```

### Home-Manager Integration

Home-manager is integrated into the NixOS configuration via `home-manager.nixosModules.home-manager`. User configuration is applied during `nixos-rebuild switch`. Standalone home-manager commands are not typically needed.

## Adding Configurations

### Adding User Packages

Edit [home/shared/packages.nix](home/shared/packages.nix) for packages all users/hosts share, and add to the `home.packages` list. For a package only one host should get, add it to that user's host-conditional list in [home/abosio/default.nix](home/abosio/default.nix):

```nix
home.packages = with pkgs; [
  # Add new package here
  new-package
];
```

### Adding System Services

Edit [hosts/logan/default.nix](hosts/logan/default.nix) for host-specific services, or the relevant module in [modules/nixos/](modules/nixos/) (create a new module for a reusable service and import it from the host):

```nix
services.myservice = {
  enable = true;
  # configuration options
};
```

### Adding Shell Aliases

abosio's aliases live in [home/abosio/default.nix](home/abosio/default.nix) under `programs.zsh.shellAliases` (the shared zsh *framework* is [home/shared/zsh.nix](home/shared/zsh.nix)):

```nix
programs.zsh.shellAliases = {
  myalias = "my command";
};
```

### Modifying Terminal Appearance

Edit [home/shared/kitty.nix](home/shared/kitty.nix) to change font, size, or theme:

```nix
programs.kitty = {
  font.name = "Font Name";
  font.size = 14;
  theme = "Theme Name";
};
```

### Adding Printers

Printers are configured declaratively in [modules/nixos/printing.nix](modules/nixos/printing.nix) using `hardware.printers.ensurePrinters`. See [docs/printer-setup.md](docs/printer-setup.md) for detailed guidance on printer discovery and configuration.

Example:
```nix
hardware.printers.ensurePrinters = [{
  name = "Printer_Name";
  location = "Home";
  deviceUri = "ipp://printer.local/ipp/port1";
  model = "drv:///driver.drv/model.ppd";
  description = "Description";
  ppdOptions = {
    PageSize = "Letter";
  };
}];
```

## Special Features

### 1Password Integration

Both CLI and GUI are enabled with PolKit integration. The 1Password GUI is configured for user "abosio" via:

```nix
programs._1password-gui = {
  enable = true;
  polkitPolicyOwners = [ "abosio" ];
};
```

### Docker

Docker is installed as a user package but the user is not in the docker group. To enable rootless Docker or add user to docker group, modify the relevant module (e.g. `modules/nixos/users.nix`).

### Non-Nix Binaries

The system has `nix-ld` enabled, allowing execution of non-Nix compiled binaries. This is configured in `modules/nixos/common.nix`:

```nix
programs.nix-ld.enable = true;
```

### Printing

CUPS printing is enabled with support for multiple printer types. The Brother HL-2170W is configured declaratively using the HL-2140 driver (closest compatible model) via hostname-based IPP connection. See [docs/printer-setup.md](docs/printer-setup.md) for details.

Printer drivers installed:
- `brlaser` - Brother laser printers
- `brgenml1lpr` / `brgenml1cupswrapper` - Brother generic drivers
- `hplip` - HP printers
- `gutenprint` - Canon, Epson, Lexmark, Sony, Olympus

## Version Control

This repository follows conventional commit format:
- `feat:` - New features
- `fix:` - Bug fixes
- `chore:` - Maintenance tasks
- `refactor:` - Code reorganization

The main branch is actively used for configuration changes.

## System Details

- **Host:** logan
- **Architecture:** x86_64-linux
- **CPU:** AMD Ryzen (kvm-amd)
- **Desktop:** GNOME with GDM
- **Shell:** zsh with extensive customization
- **Terminal:** Kitty with Nord theme
- **State Version:** 25.05
