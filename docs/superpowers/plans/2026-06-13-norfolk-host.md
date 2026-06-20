# Norfolk Host + jbosio User Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a second host `norfolk` (AMD/NVIDIA desktop, MATE desktop) and a second user `jbosio` to the flake, preserving the machine's existing `/home` HDD, while consolidating the module layout — all without changing Logan's running configuration.

**Architecture:** Three phases. **Phase 0** consolidates modules (fold tailscale/onepassword/fonts into `common.nix`; inline amdgpu+GNOME into `hosts/logan`) — every change is a behavior-identical merge, so Logan's `toplevel` store path stays equal to a baseline. **Phase 1** authors the norfolk config on Logan (host file, jbosio home, abosio host-conditional additions, flake entry) — verified by Logan staying byte-identical AND the `norfolk` attribute evaluating cleanly (it can't fully build until its real hardware file exists). **Phase 2** is the on-machine install (manual partitioning preserving the HDD, hardware-config generation, first switch) — human-run, can't be done from Logan.

**Tech Stack:** Nix flakes, NixOS modules, home-manager (NixOS module), MATE/LightDM, NVIDIA proprietary driver, `nix build` / `nix eval` / `nix store diff-closures`.

**Spec:** `docs/superpowers/specs/2026-06-13-norfolk-host-design.md`

**Prerequisite:** the multi-host refactor layout is in place. This work now lives on branch **`refactor-multiple-mac`** (which also carries the independent macOS-workstation config — see below).

---

## STATUS (updated 2026-06-19)

- **Phases 0 and 1 are COMPLETE** on `refactor-multiple-mac` (Tasks 0–8: module consolidation, the norfolk host file, jbosio home, flake `norfolk` entry, abosio's host-conditional blender + caps→ctrl, CLAUDE.md — all done and verified). The `norfolk` attribute evaluates against a **temporary stub** `hosts/norfolk/hardware-configuration.nix`.
- **Only Phase 2 (Tasks 9–12) remains** — the on-the-machine install. **Skip to Task 9.**
- **About the "Logan byte-identical" gates below:** they applied *during* Phases 0–1 and passed. Logan has since intentionally changed (26.05 deprecation-warning cleanup; abosio git identity added; the macOS branch's shared-module edits), so it is no longer identical to the original refactor baseline — that's expected and fine. Phase 2 runs entirely on the norfolk machine and does **not** modify Logan's config, so Logan is unaffected by the remaining work. The `GATE-LOGAN` baseline file (`/tmp/norfolk-logan-baseline`) from Phases 0–1 will not exist in a fresh session; Phase 2 does not need it.
- **macOS note:** the same branch defines `homeConfigurations."abosio"` (aarch64-darwin). It is independent of the norfolk install — building `.#nixosConfigurations.norfolk` does not involve the darwin output, and vice versa.
- **Before Phase 2:** push the latest branch so norfolk can clone it (local commits may be unpushed): `git push origin refactor-multiple-mac` (or merge to `main` and push).

---

## Verification Procedures

Two gates are used throughout.

**GATE-LOGAN (byte-identical):** Logan's system must not change. Used by every Phase 0/1 task that touches shared files.
```bash
git add -A
nix build .#nixosConfigurations.logan.config.system.build.toplevel \
  --no-link --print-out-paths > /tmp/norfolk-logan-now
diff <(cat /tmp/norfolk-logan-baseline) /tmp/norfolk-logan-now \
  && echo "✓ LOGAN PRESERVED" \
  || { echo "✗ LOGAN CHANGED"; nix store diff-closures "$(cat /tmp/norfolk-logan-baseline)" "$(cat /tmp/norfolk-logan-now)"; }
```
Expected: `✓ LOGAN PRESERVED`. The build prints pre-existing deprecation warnings (ssh, gpg-agent, firefox, gnome/gdm) on stderr — ignore them.

**GATE-NORFOLK-EVAL (evaluates):** Until norfolk has a real `hardware-configuration.nix`, it can't fully build, but its definition must *evaluate* without error (catches typos, bad option names, missing args). A throwaway stub hardware file makes evaluation possible.
```bash
git add -A
nix eval --raw .#nixosConfigurations.norfolk.config.system.build.toplevel.drvPath \
  && echo "✓ NORFOLK EVALUATES" \
  || echo "✗ NORFOLK EVAL FAILED"
```
Expected: a `.drv` path prints, then `✓ NORFOLK EVALUATES`.

**Commits:** single `-m`, **no `Co-Authored-By` trailer** (this repo's hooks reject it).

---

## File Structure

**Phase 0 (consolidation — Logan byte-identical):**
- Modify `modules/nixos/common.nix` — absorb tailscale + 1password + fonts.
- Modify `hosts/logan/default.nix` — inline amdgpu + GNOME desktop; drop 5 imports.
- Delete `modules/nixos/{tailscale,onepassword,fonts,amdgpu,desktop-gnome}.nix`.

**Phase 1 (norfolk authoring — on Logan):**
- Create `hosts/norfolk/default.nix` — imports + inline NVIDIA + inline MATE + users.
- Create `hosts/norfolk/hardware-configuration.nix` — **temporary stub** for evaluation; replaced on the machine in Phase 2.
- Create `home/jbosio/default.nix` — minimal home.
- Modify `home/abosio/default.nix` — norfolk-conditional blender + caps→ctrl.
- Modify `flake.nix` — add the `norfolk` host.

**Phase 2 (on-machine install — norfolk):**
- Replace `hosts/norfolk/hardware-configuration.nix` with the generated real one.
- No other repo changes; the rest is install/activation.

---

## Task 0: Capture the Logan baseline

**Files:** none.

- [ ] **Step 1: Confirm clean tree on the working branch**

Run: `git status --short && git branch --show-current`
Expected: clean; branch `refactor-multiple`.

- [ ] **Step 2: Record Logan's baseline path**

```bash
nix build .#nixosConfigurations.logan.config.system.build.toplevel \
  --no-link --print-out-paths | tee /tmp/norfolk-logan-baseline
```
Expected: one `/nix/store/...-nixos-system-logan-...` path written to `/tmp/norfolk-logan-baseline`. This is the GATE-LOGAN reference for all later tasks. (No commit.)

---

## Task 1: Fold tailscale + 1Password + fonts into `common.nix`

**Files:**
- Modify: `modules/nixos/common.nix`
- Delete: `modules/nixos/tailscale.nix`, `modules/nixos/onepassword.nix`, `modules/nixos/fonts.nix`
- Modify: `hosts/logan/default.nix` (drop the three imports)

- [ ] **Step 1: Add the three blocks to `common.nix`**

Append these inside the `common.nix` attribute set (it already takes `{ inputs, pkgs, ... }`):

```nix
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
```

- [ ] **Step 2: Delete the three now-redundant module files**

```bash
git rm modules/nixos/tailscale.nix modules/nixos/onepassword.nix modules/nixos/fonts.nix
```

- [ ] **Step 3: Remove the three imports from `hosts/logan/default.nix`**

In the `imports` list of `hosts/logan/default.nix`, delete these three lines:
```nix
    ../../modules/nixos/fonts.nix
    ../../modules/nixos/tailscale.nix
    ../../modules/nixos/onepassword.nix
```

- [ ] **Step 4: Verify Logan byte-identical**

Run the **GATE-LOGAN** block. Expected: `✓ LOGAN PRESERVED`.
(The exact same options are now set via `common.nix` instead of three imports — identical merge.)

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: fold tailscale, 1password, fonts into common.nix"
```

---

## Task 2: Inline amdgpu + GNOME desktop into `hosts/logan`

**Files:**
- Modify: `hosts/logan/default.nix`
- Delete: `modules/nixos/amdgpu.nix`, `modules/nixos/desktop-gnome.nix`

- [ ] **Step 1: Add the inlined config to `hosts/logan/default.nix`**

Add these blocks to the `hosts/logan/default.nix` attribute set (alongside the existing hostname/boot/stateVersion settings):

```nix
  # --- GPU (inlined; was amdgpu.nix) ---
  # AMD GPU drivers for hybrid graphics (RX 7600M + Radeon 680M).
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  # --- Desktop (inlined; was desktop-gnome.nix) ---
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
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
```

Keep the GNOME/GDM option names exactly as written (the deprecated `services.xserver.desktopManager.gnome.enable` / `displayManager.gdm.enable`) so the merge stays byte-identical.

- [ ] **Step 2: Remove their imports from `hosts/logan/default.nix`**

In the `imports` list, delete:
```nix
    ../../modules/nixos/desktop-gnome.nix
    ../../modules/nixos/amdgpu.nix
```
After Tasks 1–2, `hosts/logan/default.nix` imports only: `./hardware-configuration.nix`, `../../modules/nixos/common.nix`, `../../modules/nixos/printing.nix`, `../../modules/nixos/users.nix`, `../../modules/nixos/syncthing.nix`.

- [ ] **Step 3: Delete the two module files**

```bash
git rm modules/nixos/amdgpu.nix modules/nixos/desktop-gnome.nix
```

- [ ] **Step 4: Verify Logan byte-identical**

Run the **GATE-LOGAN** block. Expected: `✓ LOGAN PRESERVED`.

- [ ] **Step 5: Confirm the final module set**

Run: `ls modules/nixos/`
Expected: exactly `common.nix  printing.nix  syncthing.nix  users.nix`.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: inline amdgpu + gnome desktop into hosts/logan"
```

---

## Task 3: Add a temporary stub `hardware-configuration.nix` for norfolk

A real hardware file only exists after the on-machine `nixos-generate-config` (Phase 2). To let the `norfolk` attribute *evaluate* on Logan now, add a minimal stub that provides the options NixOS requires (a root filesystem and a boot device). **This stub is replaced in Phase 2 and must never be deployed.**

**Files:**
- Create: `hosts/norfolk/hardware-configuration.nix`

- [ ] **Step 1: Create the stub**

```nix
# hosts/norfolk/hardware-configuration.nix
# TEMPORARY STUB for flake evaluation on Logan only.
# REPLACE on the machine in Phase 2 with:
#   sudo nixos-generate-config --show-hardware-config > hosts/norfolk/hardware-configuration.nix
{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Placeholder root + ESP so the config evaluates/builds. Real UUIDs come from
  # nixos-generate-config on norfolk. The /home mount (preserved HDD) is added by
  # the generated file in Phase 2 and is intentionally NOT declared here.
  boot.loader.grub.devices = lib.mkDefault [ "nodev" ];
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
    fsType = "ext4";
  };
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
```

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "chore: add temporary stub hardware-configuration for norfolk eval"
```
(No build gate yet — norfolk isn't in the flake until Task 6.)

---

## Task 4: Create `home/jbosio/default.nix`

**Files:**
- Create: `home/jbosio/default.nix`

- [ ] **Step 1: Write jbosio's home**

```nix
# home/jbosio/default.nix
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
  ];
}
```

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "feat: add jbosio home-manager config"
```
(No gate — not referenced until the flake adds norfolk in Task 6.)

---

## Task 5: Create `hosts/norfolk/default.nix`

**Files:**
- Create: `hosts/norfolk/default.nix`

- [ ] **Step 1: Write the host file**

```nix
# hosts/norfolk/default.nix
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

  # --- GPU (GTX 1070 Ti / Pascal) ---
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = true;
    open = false;                                   # Pascal: closed modules only
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # --- Desktop (MATE on X11 + LightDM) ---
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.mate.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # WiFi: in-tree rtl8192ce needs redistributable firmware.
  hardware.enableRedistributableFirmware = true;
  # If rtlwifi power-save flakiness recurs:
  #   boot.extraModprobeConfig = "options rtl8192ce ips=0 fwlps=0";

  hardware.cpu.amd.updateMicrocode = true;

  # --- Users: pin IDs to the preserved /home HDD ---
  users.groups.abosio.gid = 1000;
  users.users.abosio = { uid = 1000; group = "abosio"; };  # augments shared users.nix

  users.groups.jbosio.gid = 1001;
  users.users.jbosio = {
    isNormalUser = true;
    uid = 1001;
    group = "jbosio";
    description = "Jayme Bosio";
    extraGroups = [ "networkmanager" ];   # non-admin: no wheel
    shell = pkgs.zsh;
  };

  system.stateVersion = "26.05";   # fresh install on this machine
}
```

Notes:
- The shared `users.nix` defines `users.users.abosio` (isNormalUser/description/extraGroups/shell); this file only *augments* it with `uid`/`group` — module merge combines them.
- `/home` is intentionally not declared here — the generated hardware file (Phase 2) provides it.

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "feat: add norfolk host (MATE + NVIDIA, jbosio account)"
```
(No gate yet — added to the flake next.)

---

## Task 6: Add norfolk to `flake.nix` and verify it evaluates

**Files:**
- Modify: `flake.nix`

- [ ] **Step 1: Add the norfolk host**

In `flake.nix`, replace the commented norfolk placeholder block inside `nixosConfigurations` with:

```nix
      norfolk = mkHost {
        hostname = "norfolk";
        users = {
          abosio = import ./home/abosio;
          jbosio = import ./home/jbosio;
        };
      };
```
(Leave the `logan = mkHost { ... }` entry unchanged.)

- [ ] **Step 2: Verify norfolk evaluates**

Run the **GATE-NORFOLK-EVAL** block. Expected: a `.drv` path, then `✓ NORFOLK EVALUATES`.
This proves the host file, jbosio home, NVIDIA/MATE options, and user merges are all syntactically and type-correct against the real nixpkgs — without needing norfolk's hardware.

- [ ] **Step 3: Verify Logan still byte-identical**

Run the **GATE-LOGAN** block. Expected: `✓ LOGAN PRESERVED`. (Adding a second host must not affect Logan.)

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: register norfolk host in flake"
```

---

## Task 7: Add abosio's norfolk-conditional blender + caps→ctrl

abosio's home is shared across Logan (GNOME) and norfolk (MATE). Both additions branch on `osConfig.networking.hostName`, so they evaluate to nothing on Logan (keeping it byte-identical) and apply only on norfolk.

**Files:**
- Modify: `home/abosio/default.nix`

- [ ] **Step 1: Extend the host-conditional `home.packages` with blender**

In `home/abosio/default.nix`, change the existing host-conditional package list from:
```nix
  home.packages =
    lib.optional (hostname != "norfolk") pkgs.obs-studio
    # ++ lib.optional (hostname == "norfolk") pkgs.pong3d   # example: norfolk-only (future)
    ;
```
to:
```nix
  home.packages =
    lib.optional (hostname != "norfolk") pkgs.obs-studio
    ++ lib.optional (hostname == "norfolk") pkgs.blender;
```

- [ ] **Step 2: Make the caps→ctrl dconf host-conditional**

In `home/abosio/default.nix`, replace the current GNOME-only dconf block:
```nix
  dconf.settings = {
    "org/gnome/desktop/input-sources" = {
      xkb-options = [ "ctrl:nocaps" ];
    };
  };
```
with a host-conditional version (GNOME key on logan; MATE key on norfolk):
```nix
  dconf.settings =
    if hostname == "norfolk" then {
      # MATE: caps->ctrl via the MATE keyboard xkb options.
      "org/mate/desktop/peripherals/keyboard/kbd" = {
        options = [ "ctrl\tctrl:nocaps" ];
      };
    } else {
      "org/gnome/desktop/input-sources" = {
        xkb-options = [ "ctrl:nocaps" ];
      };
    };
```
**Implementation note — verify on the machine:** the exact MATE dconf path/value for the xkb `ctrl:nocaps` option (`org/mate/desktop/peripherals/keyboard/kbd` `options`, entry format `"ctrl\tctrl:nocaps"`) should be confirmed on norfolk in Phase 2 against `dconf watch /` while toggling it in MATE's keyboard settings. If it doesn't take effect, use the DE-agnostic fallback instead: drop this `org/mate` branch and add an abosio-only X autostart entry running `setxkbmap -option ctrl:nocaps` (e.g. via `home.file.".config/autostart/caps-ctrl.desktop"`).

- [ ] **Step 3: Verify Logan byte-identical**

Run the **GATE-LOGAN** block. Expected: `✓ LOGAN PRESERVED`.
On Logan, `hostname == "logan"`, so blender isn't added and the dconf `else` branch reproduces the original GNOME setting exactly — byte-identical.

- [ ] **Step 4: Verify norfolk still evaluates**

Run the **GATE-NORFOLK-EVAL** block. Expected: `✓ NORFOLK EVALUATES`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: norfolk-only blender + MATE caps->ctrl for abosio"
```

---

## Task 8: Update `CLAUDE.md` for the two-host, consolidated layout

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update the File Organization tree**

In `CLAUDE.md`, update the `### File Organization` block to show both hosts and the consolidated module set:

```text
flake.nix                       # Entry point - mkHost helper, declares logan + norfolk
├── hosts/
│   ├── logan/                  # AMD laptop, GNOME (GPU + desktop inline)
│   │   ├── default.nix
│   │   └── hardware-configuration.nix
│   └── norfolk/                # NVIDIA desktop, MATE (GPU + desktop inline); user jbosio
│       ├── default.nix
│       └── hardware-configuration.nix
├── modules/nixos/              # Shared system modules (imported per host)
│   ├── common.nix              # Base every machine gets (incl. tailscale, 1password, fonts)
│   ├── printing.nix            # CUPS + Brother printer
│   ├── syncthing.nix           # Host-aware syncthing
│   └── users.nix               # Shared abosio account
├── home/
│   ├── shared/                 # kitty, packages, zsh (framework)
│   ├── abosio/default.nix      # abosio (host-conditional: obs on logan, blender on norfolk)
│   └── jbosio/default.nix      # Jayme (norfolk only)
└── docs/
```

- [ ] **Step 2: Update prose references**

In `CLAUDE.md`:
- Repository Overview: change "currently for a single host named logan" to note two hosts, `logan` (AMD/GNOME laptop) and `norfolk` (NVIDIA/MATE desktop) with users `abosio` and `jbosio`.
- "Adding System Services": single-host hardware/desktop now lives inline in each host's `default.nix`; reusable services go in `modules/nixos/` (now `common`, `printing`, `syncthing`, `users`).
- Note that tailscale, 1Password, and fonts are part of `common.nix` (no longer separate modules).

- [ ] **Step 3: Verify Logan byte-identical (docs don't affect the build)**

Run the **GATE-LOGAN** block. Expected: `✓ LOGAN PRESERVED`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "docs: update CLAUDE.md for norfolk host + consolidated modules"
```

---

## Task 9 (ON NORFOLK): Install NixOS preserving the /home HDD

**This task runs on the norfolk machine, not Logan.** It cannot be done from Logan. Run Claude here via `nix run nixpkgs#claude-code` if desired, or follow manually.

- [ ] **Step 1: Boot the graphical NixOS installer ISO and connect WiFi**

Boot the **graphical (GNOME) NixOS 26.05 ISO**. Connect WiFi via `nmtui` (the in-tree `rtl8192ce` driver + firmware are on the ISO):
```bash
nmtui   # select the SSID, enter the password
ping -c2 abosio.com   # confirm connectivity (needed for nixos-secrets at build)
```

- [ ] **Step 2: Identify disks and confirm the HDD to preserve**

```bash
lsblk -f
```
Expected: `sda1` = ext4, UUID `26b3c25e-267a-4717-a091-f77f050b01e3`, ~1.8 TB (the `/home` HDD to **preserve**). `sdb` = the Ubuntu SSD (ESP + /boot + LVM) — the install target.

- [ ] **Step 2a: Back up before destructive partitioning (judgment gate)**

If anything important remains on the SSD (`sdb`) or you have any doubt, stop and back it up. The next step **erases `sdb`**. Confirm `sda` is the ~1.8 TB ext4 home disk and `sdb` is the SSD before proceeding. If `lsblk` doesn't match the spec (different sizes/UUIDs), STOP — the machine's layout changed since recon.

- [ ] **Step 3: Partition the SSD (sdb) — leave sda untouched**

Create a fresh GPT on **`sdb` only**: an ESP and a root partition. Do **not** touch `sda`. Example with `parted` (adjust device if needed):
```bash
sudo parted /dev/sdb -- mklabel gpt
sudo parted /dev/sdb -- mkpart ESP fat32 1MiB 1025MiB
sudo parted /dev/sdb -- set 1 esp on
sudo parted /dev/sdb -- mkpart primary ext4 1025MiB 100%
sudo mkfs.fat -F32 -n boot /dev/sdb1
sudo mkfs.ext4 -L nixos /dev/sdb2
```

- [ ] **Step 4: Mount target root, ESP, and the preserved /home**

```bash
sudo mount /dev/sdb2 /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/sdb1 /mnt/boot
sudo mkdir -p /mnt/home
sudo mount /dev/disk/by-uuid/26b3c25e-267a-4717-a091-f77f050b01e3 /mnt/home   # PRESERVE: mount, do NOT mkfs
```
Verify `/mnt/home` shows the existing `abosio/` and `jbosio/` directories:
```bash
ls -ln /mnt/home    # expect abosio (1000) and jbosio (1001) dirs intact
```

- [ ] **Step 5: Generate the real hardware configuration**

```bash
sudo nixos-generate-config --root /mnt
```
This writes `/mnt/etc/nixos/hardware-configuration.nix` with the real root, ESP, **and `/home`** mounts (because `/mnt/home` is mounted). Confirm it contains a `fileSystems."/home"` entry pointing at the `26b3c25e-…` UUID and a `fileSystems."/"` for the SSD root:
```bash
grep -A3 'fileSystems."/home"' /mnt/etc/nixos/hardware-configuration.nix
grep -A3 'fileSystems."/"' /mnt/etc/nixos/hardware-configuration.nix
```

---

## Task 10 (ON NORFOLK): Wire in the real hardware file and switch

- [ ] **Step 0 (PREREQUISITE, done earlier on Logan): make the branch reachable**

norfolk clones the config over the network, so the branch carrying norfolk must be pushed (or merged to `main`) **before** this step. From Logan: `git push origin refactor-multiple-mac` (or merge to `main` and push). Confirm `git ls-remote origin refactor-multiple-mac` (or `main`) shows the latest commit.

- [ ] **Step 1: Get the repo and SSH access to nixos-secrets**

Clone the config and ensure SSH auth to the secrets repo works (the flake's `common.nix` fetches the Caddy CA from `nixos-secrets` at build time):
```bash
git clone git@github.com:abosio/nixos-config.git /mnt/home/abosio/nixos-config
cd /mnt/home/abosio/nixos-config
git checkout refactor-multiple-mac    # the branch with norfolk (or main, if merged)
ssh -T abosio@abosio.com -p 1022 || true   # confirm the secrets-repo key is available (1Password/agent)
```
(HTTPS clone is fine too if SSH to GitHub isn't set up on the live ISO — only `nixos-secrets` strictly needs SSH auth.)

- [ ] **Step 2: Replace the stub hardware file with the generated one**

```bash
cp /mnt/etc/nixos/hardware-configuration.nix hosts/norfolk/hardware-configuration.nix
git add hosts/norfolk/hardware-configuration.nix
git status --short    # confirm the stub is now replaced by the real file
```
Sanity-check it no longer contains the placeholder all-zero UUID and DOES contain the `/home` mount.

- [ ] **Step 3: Build norfolk (full build now possible)**

```bash
sudo nixos-rebuild build --flake .#norfolk
```
Expected: a successful build (downloads the NVIDIA driver, MATE, etc.). Resolve any evaluation/build errors before switching. If the build needs the secrets repo and fails on SSH, fix auth (Step 1) and retry.

- [ ] **Step 4: Install/activate**

If installing from the live ISO:
```bash
sudo nixos-install --flake .#norfolk --root /mnt
```
(Or, if already running a NixOS base system: `sudo nixos-rebuild switch --flake .#norfolk`.)

- [ ] **Step 5: Set passwords and reboot**

```bash
sudo nixos-enter --root /mnt    # if from installer
passwd abosio
passwd jbosio
exit
sudo reboot
```

- [ ] **Step 6: Commit the real hardware file**

After confirming a good boot (next task), commit:
```bash
git commit -m "feat: add norfolk real hardware-configuration.nix"
```
This replaces the temporary stub from Task 3 in version control.

---

## Task 11 (ON NORFOLK): Post-boot verification

- [ ] **Step 1: Confirm desktop + GPU**

Log in via LightDM into MATE. Then:
```bash
nvidia-smi                       # driver loads, GTX 1070 Ti listed
glxinfo | grep "OpenGL renderer" # NVIDIA renderer (install mesa-demos if needed)
echo $XDG_SESSION_TYPE           # expect x11
```

- [ ] **Step 2: Confirm /home preserved with correct ownership**

```bash
ls -ln /home                     # abosio dir uid 1000, jbosio dir uid 1001
id abosio                        # uid=1000 gid=1000(abosio)
id jbosio                        # uid=1001 gid=1001(jbosio)
sudo -u abosio test -r /home/abosio && echo "abosio can read own home"
```
Existing files should still be owned by the matching users (the uid/gid pinning preserved them).

- [ ] **Step 3: Confirm network + reconnect WiFi if needed**

```bash
nmtui          # reconnect WiFi in the installed system (live-env connection isn't carried over)
tailscale status
```

- [ ] **Step 4: Confirm caps→ctrl for abosio under MATE**

As abosio in a MATE session, press CapsLock and verify it behaves as Ctrl (e.g. CapsLock+C copies). If not, apply the `setxkbmap` autostart fallback from Task 7 Step 2, rebuild, and re-test.

- [ ] **Step 5: Confirm Blender launches** for both abosio and jbosio (`blender --version`).

- [ ] **Step 6: Confirm syncthing** is running and paired with gotham + MBP:
```bash
systemctl status syncthing.service
# Web UI at http://127.0.0.1:8384 — gotham + MBP should appear as devices
```

---

## Task 12: Final review

- [ ] **Step 1: Confirm Phase 2 only touched the norfolk hardware file**

Phase 2 must not change any shared or Logan config — its only repo change is the real `hosts/norfolk/hardware-configuration.nix` (replacing the stub). Confirm with:
```bash
git diff --stat <commit-before-phase-2>..HEAD
```
Expected: only `hosts/norfolk/hardware-configuration.nix` is changed. (A full `GATE-LOGAN` byte-comparison isn't meaningful here — Logan changed intentionally after Phases 0–1, and the baseline file is gone. The point is simply that the install added the norfolk hardware file and nothing else.) Logan can be rebuilt independently and is unaffected.

- [ ] **Step 2: Confirm the tree shape**

```bash
ls modules/nixos/        # common.nix printing.nix syncthing.nix users.nix
ls hosts                 # logan norfolk
ls home                  # abosio jbosio shared
```

- [ ] **Step 3 (optional follow-up): logan↔norfolk syncthing**

To pair Logan and norfolk (beyond gotham/MBP): grab norfolk's syncthing device ID (from its web UI or `cat /home/abosio/.config/syncthing/config.xml`), grab Logan's, and add both to `${nixos-secrets}/syncthing-devices.nix`. The host-aware module then gives each host the other automatically. This is a separate change to the `nixos-secrets` repo — out of scope for norfolk coming up.

---

## Done

norfolk runs MATE on the NVIDIA driver with both users' `/home` preserved; the module layout is consolidated to `{common, printing, syncthing, users}`; and Logan is unaffected by the on-machine install (it was rebuilt/activated separately during the earlier phases). The temporary stub hardware file is replaced by the machine's real one. Follow-up: logan↔norfolk syncthing pairing (Task 12 Step 3).
