# Norfolk Host + jbosio User — Design

**Date:** 2026-06-13
**Status:** Approved for planning
**Builds on:** the completed multi-host refactor (`docs/superpowers/specs/2026-06-02-multi-host-refactor-design.md`, layout currently on branch `refactor-multiple`). The hardware recon for this machine is the "Appendix: Norfolk Hardware Notes" in that spec.

## Goal

Add a second host, **norfolk** — an AMD/NVIDIA desktop currently running Ubuntu MATE
under the hostname `galactica` — and a second user, **jbosio** (Jayme), to the
flake. norfolk runs a MATE desktop, preserves the machine's existing `/home` HDD,
and reuses the shared modules. As part of this work, consolidate the module layout
so single-use and trivial-universal configs stop living in `modules/nixos/`.

## Constraints & invariants

- **Logan stays byte-for-byte identical.** Every change to shared files
  (`common.nix`, `hosts/logan/default.nix`, `home/abosio/default.nix`) is either a
  behavior-identical merge (inlining/folding) or gated behind
  `osConfig.networking.hostName == "norfolk"`, so it evaluates to nothing on Logan.
  Verification: Logan's `system.build.toplevel` store path must equal its
  pre-change baseline (same gate used in the refactor).
- **Preserve the existing `/home` HDD** — mount it, never format it.
- **`jbosio` is non-admin** (no `wheel`), matching her Ubuntu account.
- **MATE is swappable** — chosen for now; the desktop config is isolated enough
  that switching later is a localized edit.

## Module consolidation (Phase 0 — prerequisite restructuring)

The refactor's fine-grained split produced files that don't earn their keep.
Apply the rule: *a config used by exactly one host lives in that host's
`default.nix`; only substantial, self-contained configs shared across hosts get a
file in `modules/nixos/`.*

- **Fold into `common.nix`** (every host gets them; small): the contents of
  `tailscale.nix` (`services.tailscale.enable = true`), `onepassword.nix`
  (`_1password` + GUI + `polkitPolicyOwners = [ "abosio" ]`), and `fonts.nix`
  (Fira Code + fontconfig + fontDir). Delete those three files.
- **Inline into `hosts/logan/default.nix`** (single-host): the contents of
  `amdgpu.nix` and `desktop-gnome.nix`. Delete those two files.

Resulting `modules/nixos/` = **`common.nix`, `printing.nix`, `syncthing.nix`,
`users.nix`** (printing and syncthing are real subsystems; users holds the shared
`abosio` account). All of this is behavior-identical for Logan.

## New & changed files

```
modules/nixos/
  common.nix          # + tailscale, 1password, fonts folded in
  printing.nix        # unchanged
  syncthing.nix       # unchanged (host-aware; norfolk now imports it)
  users.nix           # unchanged (shared abosio account)
  amdgpu.nix          # DELETED (inlined into hosts/logan)
  desktop-gnome.nix   # DELETED (inlined into hosts/logan)
  tailscale.nix       # DELETED (folded into common)
  onepassword.nix     # DELETED (folded into common)
  fonts.nix           # DELETED (folded into common)

hosts/logan/default.nix     # + inline amdgpu + inline GNOME desktop; drop the 5 dropped imports
hosts/norfolk/
  default.nix               # NEW
  hardware-configuration.nix# NEW (generated on the machine)

home/abosio/default.nix     # + norfolk-conditional MATE caps->ctrl dconf; + norfolk-conditional blender
home/jbosio/default.nix     # NEW

flake.nix                   # uncomment/fill the norfolk = mkHost {...} block
```

## hosts/norfolk/default.nix

Imports the shared set; inlines norfolk-only hardware and desktop:

```nix
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/common.nix
    ../../modules/nixos/printing.nix
    ../../modules/nixos/syncthing.nix
    ../../modules/nixos/users.nix       # shared abosio account
  ];

  networking.hostName = "norfolk";

  # Boot — confirmed UEFI.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # --- GPU (inline; GTX 1070 Ti / Pascal) ---
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = true;
    open = false;                                   # Pascal: closed modules only
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # --- Desktop (inline; MATE on X11 + LightDM) ---
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.mate.enable = true;
  services.xserver.xkb = { layout = "us"; variant = ""; };

  # WiFi: in-tree rtl8192ce needs redistributable firmware.
  hardware.enableRedistributableFirmware = true;
  # If the rtlwifi power-save flakiness recurs, add:
  #   boot.extraModprobeConfig = "options rtl8192ce ips=0 fwlps=0";

  hardware.cpu.amd.updateMicrocode = true;

  # --- Users: pin IDs to the preserved HDD ---
  users.groups.abosio.gid = 1000;
  users.users.abosio = { uid = 1000; group = "abosio"; };   # augments shared users.nix

  users.groups.jbosio.gid = 1001;
  users.users.jbosio = {
    isNormalUser = true;
    uid = 1001;
    group = "jbosio";
    description = "Jayme Bosio";
    extraGroups = [ "networkmanager" ];   # NO wheel — non-admin
    shell = pkgs.zsh;
  };

  system.stateVersion = "26.05";   # fresh install on this machine
}
```

Notes:
- The function head needs `config` (for `nvidiaPackages`) and `pkgs` (for the
  shell) — use `{ config, pkgs, ... }:`.
- `system.stateVersion` is the release norfolk is first installed at (26.05 with
  the current flake), kept separate from Logan's `25.05`.

### `/home` preservation (not declared here)

The generated `hardware-configuration.nix` will pick up the `/home` mount
**provided the HDD is mounted when `nixos-generate-config` runs during install**.
Target: `/dev/disk/by-uuid/26b3c25e-267a-4717-a091-f77f050b01e3` (ext4, ~1.8 TB).
We do **not** also declare `fileSystems."/home"` in `default.nix` (that would
conflict with the generated entry). The implementation plan must verify the
generated hardware file contains the `/home` mount before first switch.

## home/jbosio/default.nix

```nix
{ pkgs, ... }:
{
  imports = [
    ../shared/kitty.nix
    ../shared/zsh.nix          # framework only (no aliases)
  ];

  home.username = "jbosio";
  home.homeDirectory = "/home/jbosio";
  home.stateVersion = "26.05"; # her own, new user

  programs.home-manager.enable = true;
  programs.firefox.enable = true;

  home.packages = with pkgs; [
    blender                    # norfolk runs it; jbosio exists only on norfolk
    # grow over time
  ];
}
```

Because jbosio exists only on norfolk, her `blender` needs no host conditional.

## home/abosio/default.nix changes

Two norfolk-conditional additions, both keyed on
`hostname = osConfig.networking.hostName` (the existing pattern). On Logan they
evaluate to nothing, so Logan stays byte-identical.

1. **Blender on norfolk** — extend the existing host-conditional `home.packages`:
   ```nix
   home.packages =
     lib.optional (hostname != "norfolk") pkgs.obs-studio
     ++ lib.optional (hostname == "norfolk") pkgs.blender;
   ```

2. **caps→ctrl on MATE** — abosio-only, two implementations (Jayme is unaffected).
   Logan keeps the existing GNOME dconf key; norfolk gets MATE's equivalent. Make
   the dconf settings host-conditional, e.g.:
   ```nix
   dconf.settings =
     if hostname == "norfolk" then {
       # MATE keyboard xkb options — EXACT key/format to be verified during
       # implementation (org.mate keyboard-xkb schema). Fallback if dconf proves
       # unreliable: a per-user `setxkbmap -option ctrl:nocaps` via an X autostart
       # entry in abosio's home (still abosio-only, DE-agnostic).
     } else {
       "org/gnome/desktop/input-sources" = { xkb-options = [ "ctrl:nocaps" ]; };
     };
   ```
   **Open implementation detail:** confirm the MATE dconf path/value for the
   `ctrl:nocaps` xkb option on the actual machine; adopt the `setxkbmap` autostart
   fallback if needed.

## flake.nix

Uncomment/fill the reserved block:

```nix
norfolk = mkHost {
  hostname = "norfolk";
  users = {
    abosio = import ./home/abosio;
    jbosio = import ./home/jbosio;
  };
};
```

## Syncthing follow-up (out of initial scope, documented)

norfolk imports the host-aware `syncthing.nix`. With today's secrets file
(`gotham` + `MBP` only), norfolk immediately syncs with gotham + MBP. To enable
**logan↔norfolk** syncing, a follow-up adds both device IDs to
`${nixos-secrets}/syncthing-devices.nix` after norfolk's syncthing generates its
device ID on first boot. Not required for norfolk to come up.

## Install procedure (manual)

NixOS auto-detection won't handle the NVIDIA driver, WiFi quirks, or `/home`
preservation, so the install is deliberate:

1. **Network for install — WiFi (no ethernet needed):** norfolk's WiFi
   (`rtl8192ce`) is an in-tree driver whose firmware ships on the NixOS ISO, so
   connect over **WiFi** in the live installer. Use the **graphical (GNOME) ISO**
   and connect via `nmtui` or the network applet (SSID + password). Ethernet
   (`r8169`) is a fallback if a cable can reach, but is **not required**. The
   flake's `common.nix` fetches the Caddy CA from `nixos-secrets` over SSH at
   build time, so norfolk needs network + SSH access to that repo before the first
   build — the live env's WiFi connection satisfies this.
2. Boot the graphical NixOS installer ISO.
3. **Partition manually:** repartition/format the **SSD (`sdb`)** for NixOS
   (ESP + root); **mount but do NOT format the HDD (`sda1`) at `/home`.** No
   declarative `disko` — it likes to own/wipe disks, the opposite of preserving
   `/home`.
4. `nixos-generate-config` with `/home` mounted →
   `hosts/norfolk/hardware-configuration.nix`; confirm the `/home` and root
   entries are present and the GPU/UEFI bits look right.
5. Ensure SSH access to `nixos-secrets`, then
   `nixos-rebuild switch --flake .#norfolk` (or `nixos-install` from the ISO).
6. Set passwords (`passwd abosio`, `passwd jbosio`).
7. **After first boot into the installed system, reconnect WiFi** via the MATE
   network applet or `nmtui` — the live installer's WiFi connection is not carried
   into the installed system. NetworkManager (from `common.nix`) + the firmware
   (`enableRedistributableFirmware`) are already present, so it's just entering the
   SSID/password once. (WiFi credentials are entered interactively, not committed
   to the public config; if declarative WiFi is wanted later, do it via a sops
   secret.)

## Success criteria

- norfolk boots into MATE via LightDM with the NVIDIA proprietary driver (X11).
- Networking works over WiFi (in-tree `rtl8192ce` + redistributable firmware),
  both in the installer and the installed system; ethernet available but optional.
- Both users' data on the preserved `/home` HDD is intact with correct ownership
  (`abosio` 1000:1000, `jbosio` 1001:1001).
- caps→ctrl works for abosio under MATE; Jayme's keyboard is unaffected.
- Blender runs for both users.
- **Logan's `toplevel` store path is unchanged** from before this work.

## Out of scope

- Gaming layer (Steam/etc.) — general desktop only for now; add later.
- logan↔norfolk syncthing pairing (the device-ID follow-up above).
- Replicating Ubuntu MATE's specific theme/layout (upstream MATE defaults; can be
  themed declaratively later if desired).
- Declarative partitioning (`disko`).
```
