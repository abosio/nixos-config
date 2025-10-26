# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a flake-based NixOS configuration for a desktop machine named "logan". The configuration uses a three-layer architecture:
- **System Layer** - Core NixOS configuration (configuration.nix)
- **User Layer** - Home-manager based user environment (home.nix)
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
flake.nix                      # Entry point - declares inputs and system output
├── configuration.nix          # System-wide configuration
│   └── hardware-configuration.nix  # Auto-generated (DO NOT EDIT)
└── home.nix                   # Home-manager root
    ├── kitty.nix              # Terminal configuration
    ├── packages.nix           # User packages (29 packages)
    └── zsh.nix                # Shell configuration
```

### Flake Inputs

- **nixpkgs** - NixOS packages (nixos-25.05)
- **home-manager** - User environment management (release-25.05)
- **sops-nix** - Secrets encryption (infrastructure ready, minimal current use)
- **nixos-secrets** - Private SSH repository
  - Currently used for Syncthing device configuration
  - Accessed via `inputs.nixos-secrets` in configuration files

### Configuration Layers

**System Configuration (configuration.nix):**
- Hostname, bootloader, networking
- Display (X11 + GNOME), audio (PipeWire)
- Services: OpenSSH, Syncthing, Avahi mDNS, auto-upgrade
- Security: 1Password integration, nix-ld for non-Nix binaries
- NFS mount for Raspberry Pi 5 at /mnt/pi
- User definition for "abosio"

**Home-Manager (home.nix + modules):**
- Programs: Firefox, Thunderbird, SSH, GPG agent
- Keyboard remapping: CAPS LOCK to CTRL (via dconf)
- Modular imports for terminal, packages, and shell config

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
- General LAN service discovery

### Hardware Configuration

The file [hardware-configuration.nix](hardware-configuration.nix) is auto-generated. Do not manually edit it. To regenerate:

```bash
sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
```

### Home-Manager Integration

Home-manager is integrated into the NixOS configuration via `home-manager.nixosModules.home-manager`. User configuration is applied during `nixos-rebuild switch`. Standalone home-manager commands are not typically needed.

## Adding Configurations

### Adding User Packages

Edit [packages.nix](packages.nix) and add packages to the `home.packages` list:

```nix
home.packages = with pkgs; [
  # Add new package here
  new-package
];
```

### Adding System Services

Edit [configuration.nix](configuration.nix) under the `services` section:

```nix
services.myservice = {
  enable = true;
  # configuration options
};
```

### Adding Shell Aliases

Edit [zsh.nix](zsh.nix) in the `shellAliases` section:

```nix
shellAliases = {
  myalias = "my command";
};
```

### Modifying Terminal Appearance

Edit [kitty.nix](kitty.nix) to change font, size, or theme:

```nix
programs.kitty = {
  font.name = "Font Name";
  font.size = 14;
  theme = "Theme Name";
};
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

Docker is installed as a user package but the user is not in the docker group. To enable rootless Docker or add user to docker group, modify configuration.nix.

### Non-Nix Binaries

The system has `nix-ld` enabled, allowing execution of non-Nix compiled binaries. This is configured in configuration.nix:

```nix
programs.nix-ld.enable = true;
```

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
