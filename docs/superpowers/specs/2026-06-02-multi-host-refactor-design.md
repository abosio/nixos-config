# Multi-Host Refactor Design — Logan

**Date:** 2026-06-02
**Branch:** `refactor-multiple`
**Status:** Approved for planning

## Background

This NixOS configuration currently manages a single host, `logan`, via a
monolithic `configuration.nix` plus flat home-manager files (`home.nix`,
`kitty.nix`, `packages.nix`, `zsh.nix`). A mentor's guidance document
([rochecompaan/nixos-anthony, lesson 08](https://github.com/rochecompaan/nixos-anthony/blob/main/08-refactoring-for-multiple-machines.md))
describes refactoring toward a `hosts/` + `modules/` + `home/<user>/` layout so a
second machine and a second user can be added cleanly.

The current flake is already **ahead** of that document in places: it is on
`nixos-26.05` (the doc assumes `25.11`) and already wires `nixpkgs-unstable` /
`pkgs-unstable` through `home-manager.extraSpecialArgs` and `inputs` through
`specialArgs`. The doc's remaining value is the **structural** refactor, which
has not been done.

## Goal

Restructure Logan into a multi-host layout that is forward-compatible with a
future second host (`norfolk`, an old-NVIDIA desktop) and a second user
(`jayme`) — **without changing Logan's runtime behavior**.

## Scope

**In scope (this effort):**

- Split `configuration.nix` into `modules/nixos/*.nix` + `hosts/logan/default.nix`.
- Move `hardware-configuration.nix` into `hosts/logan/` unchanged.
- Split home-manager into `home/shared/*` + `home/abosio/default.nix`.
- Adopt a `mkHost` helper in `flake.nix`.
- Verify Logan builds to an identical system derivation.

**Out of scope (deferred to a future spec):**

- `hosts/norfolk/` and its `hardware-configuration.nix` (needs the physical machine).
- `home/jayme/` and the `jayme` system account.
- `modules/nixos/nvidia.nix` (needs the exact GPU identified on the machine).
- Preserving Norfolk's existing `/home` HDD and UID matching.
- Any install / `nixos-rebuild switch` on Norfolk.

The layout produced here reserves space for all of the above so adding them later
is additive.

## Success Criterion (provable)

The refactor must be **behavior-preserving** for Logan. NixOS modules merge, so
splitting options across files is safe as long as no option is dropped or
changed. Acceptance test: compare the `system.build.toplevel` store path before
and after the refactor.

```bash
# Before refactoring (clean tree at the starting commit):
nix build .#nixosConfigurations.logan.config.system.build.toplevel --no-link --print-out-paths
#   -> record path A

# After refactoring (new files staged — git-backed flakes ignore untracked files):
git add -A
nix build .#nixosConfigurations.logan.config.system.build.toplevel --no-link --print-out-paths
#   -> path B
```

**Path A must equal path B.** An identical store path proves the configuration is
byte-for-byte unchanged. (`nvd diff A B` may be used for a human-readable
confirmation, but path equality is the gate.)

## Target Directory Layout

```text
flake.nix                       # mkHost helper; logan only (norfolk added later)

hosts/
  logan/
    default.nix                 # module imports + logan-only settings
    hardware-configuration.nix  # moved verbatim, never hand-edited
  # norfolk/                    # reserved — future spec

modules/nixos/
  common.nix                    # base every fleet machine gets
  fonts.nix
  desktop-gnome.nix
  printing.nix
  tailscale.nix
  onepassword.nix
  users.nix                     # abosio system account (jayme added later)
  syncthing.nix                 # host-aware; logan-only import for now
  amdgpu.nix
  # nvidia.nix                  # reserved — future spec

home/
  shared/
    kitty.nix
    packages.nix                # base set (both users/hosts); host-specific pkgs added per-host
    zsh.nix                     # zsh framework only (no aliases)
  abosio/
    default.nix                 # imports shared/*; aliases + host-conditional pkgs + abosio config
  # jayme/                      # reserved — future spec
```

## Settings Classification

This is the authoritative mapping of every current setting to its new home. The
implementation must place every listed option and drop none.

### `modules/nixos/common.nix` — base every machine gets

- `nix.settings.experimental-features = [ "nix-command" "flakes" ]`
- `nixpkgs.config.allowUnfree = true`
- `nixpkgs.config.permittedInsecurePackages = [ "electron-39.8.10" ]` (logseq;
  applies fleet-wide because `useGlobalPkgs = true` makes home packages use the
  system `nixpkgs.config`)
- `system.autoUpgrade.enable = true; allowReboot = false`
- `networking.networkmanager.enable = true`
- `networking.extraHosts` (the `git.abosio.com` entry)
- `services.avahi.enable = true; nssmdns4 = true`
- `services.openssh.enable = true`
- `time.timeZone = "America/New_York"`
- `i18n.defaultLocale` + `i18n.extraLocaleSettings`
- `services.pulseaudio.enable = false; security.rtkit.enable = true;`
  `services.pipewire` (alsa + 32-bit + pulse)
- `programs.zsh.enable = true`
- `programs.nix-ld.enable = true`
- `environment.systemPackages = [ vim ]`
- `security.pki.certificateFiles = [ "${inputs.nixos-secrets}/caddy-root-ca.crt" ]`

`common.nix` is flat/inline base only. It does **not** import the feature modules;
the host imports those. (Rationale: explicit per-host imports keep each machine's
feature set obvious and let a future non-desktop host opt out.)

### Feature modules (one concern each; imported by the host)

| File | Contents |
|------|----------|
| `fonts.nix` | `fonts.packages = [ fira-code ]`, `fontconfig.enable`, `fontDir.enable` |
| `desktop-gnome.nix` | `services.xserver.enable`, gdm, gnome, `xkb` (us), `programs.dconf` with the gnome-terminal Fira Code 14 profile |
| `printing.nix` | `services.printing.enable` + drivers, `services.avahi.publish.*`, the `Brother_HL-2170W` `ensurePrinters` entry |
| `tailscale.nix` | `services.tailscale.enable = true` |
| `onepassword.nix` | `programs._1password.enable`, `programs._1password-gui.enable`, `polkitPolicyOwners = [ "abosio" ]` |
| `users.nix` | `users.users.abosio` (isNormalUser, description, `extraGroups = [ "networkmanager" "wheel" ]`, `shell = pkgs.zsh`) |
| `amdgpu.nix` | `services.xserver.videoDrivers = [ "amdgpu" ]`, `hardware.graphics.enable`, `hardware.graphics.enable32Bit` |
| `syncthing.nix` | host-aware syncthing — see below |

### `hosts/logan/default.nix` — Logan-only

Inline settings:

- `networking.hostName = "logan"`
- `boot.loader.systemd-boot.enable = true; boot.loader.efi.canTouchEfiVariables = true`
- `fileSystems."/mnt/pi"` (the raspberrypi5 NFS automount)
- `system.stateVersion = "25.05"`

Imports:

```nix
imports = [
  ./hardware-configuration.nix
  ../../modules/nixos/common.nix
  ../../modules/nixos/fonts.nix
  ../../modules/nixos/desktop-gnome.nix
  ../../modules/nixos/printing.nix
  ../../modules/nixos/tailscale.nix
  ../../modules/nixos/onepassword.nix
  ../../modules/nixos/users.nix
  ../../modules/nixos/amdgpu.nix
  ../../modules/nixos/syncthing.nix
];
```

## Deliberate Deviations From the Mentor Doc

These are intentional corrections; the user has approved them.

1. **`system.stateVersion` lives in the host file, not `common.nix`.** The doc
   places it in common. `stateVersion` records the NixOS release a machine was
   *first installed* at and must never change for that machine — so it is
   inherently per-host. A shared value would force the future `norfolk` to
   inherit Logan's `25.05` incorrectly.

2. **Bootloader lives in the host file, not `common.nix`.** Norfolk is an old
   NVIDIA box that may be legacy-BIOS (GRUB) rather than Logan's UEFI
   `systemd-boot`. Per-host bootloader avoids a hard-to-debug boot failure later.

3. **`syncthing.nix` is host-aware and Logan-only-imported for now.** It still
   hardcodes `user = "abosio"` and `/home/abosio` paths, so it is not yet truly
   shared. It is written host-agnostic (see below) so Norfolk can import the same
   file unchanged later, but only Logan imports it in this refactor.

## Host-Aware Syncthing

Syncthing device membership varies by host with overlap: each host should sync
with every *other* device, never itself. Today Logan syncs with `gotham` + `MBP`;
later Logan will also include `norfolk`, and `norfolk` will include `logan` +
`gotham` + `MBP`.

`modules/nixos/syncthing.nix` self-selects by filtering the host's own name out
of the full device set:

```nix
{ config, inputs, lib, ... }:
let
  allDevices = import "${inputs.nixos-secrets}/syncthing-devices.nix";
  devices = lib.filterAttrs (name: _: name != config.networking.hostName) allDevices;
in
{
  services.syncthing = {
    enable = true;
    user = "abosio";
    openDefaultPorts = true;
    dataDir = "/home/abosio/.local/share/syncthing";
    configDir = "/home/abosio/.config/syncthing";
    settings.devices = devices;
  };
}
```

**Behavior preservation:** `syncthing-devices.nix` currently contains only
`gotham` + `MBP` (no `logan` key), so filtering out `"logan"` is a no-op — the
device set is unchanged and the `toplevel` store path stays identical.

**Future scaling (out of scope, documented for continuity):** add `logan` and
`norfolk` device IDs to `syncthing-devices.nix` (in the `nixos-secrets` repo).
Logan then resolves to `{norfolk, gotham, MBP}` and Norfolk to
`{logan, gotham, MBP}` automatically — one ID added per new host, no per-host
duplication.

## Home-Manager Split

The home layer separates a shared base from abosio-specific config, and scaffolds
the per-host package-divergence pattern so abosio's package set can differ between
Logan and Norfolk later. `osConfig` (the system configuration) is automatically
available inside home-manager modules when home-manager runs as a NixOS module, so
`osConfig.networking.hostName` is the branch key — no flake change needed.

### `home/shared/`

- `kitty.nix` — moved verbatim.
- `packages.nix` — the base package set both hosts/users get. Receives
  `pkgs-unstable` via the existing `home-manager.extraSpecialArgs` (no flake change
  needed). Host-specific packages do **not** live here; `obs-studio` moves out of
  this base into abosio's host-conditional list (below).
- `zsh.nix` — the zsh **framework only**: `enable`, `enableCompletion`, `history`,
  `sessionVariables`, `syntaxHighlighting`, `zplug` plugins, and `initContent`
  (prompt, keybindings, zoxide init). **No `shellAliases`** — every current alias
  is abosio-specific and moves to `home/abosio`.

### `home/abosio/default.nix`

Imports `../shared/kitty.nix`, `../shared/packages.nix`, `../shared/zsh.nix`, and
holds abosio's configuration. Function args include `osConfig` and `lib` for the
host branch:

- `home.username = "abosio"`, `home.homeDirectory = "/home/abosio"`
- `home.stateVersion = "25.05"` — per-user compatibility marker, kept consistent
  for abosio across all hosts (see note below). Unlike `system.stateVersion`, this
  is **not** per-machine.
- `programs.home-manager.enable = true`
- `programs.firefox.enable`
- `programs.thunderbird` (default profile)
- `programs.ssh` (matchBlocks for `raspberrypi5`, `git.abosio.com`; the
  `IdentityAgent` + `SetEnv` extraConfig)
- `services.gpg-agent` (ssh support, gnome3 pinentry)
- `dconf.settings` caps→ctrl (`xkb-options = [ "ctrl:nocaps" ]`)
- **All `programs.zsh.shellAliases`** from the current `zsh.nix` — navigation
  (`ls`/`ll`/`la`), convenience (`grep`/`cat`), safety (`cp`/`mv`/`rm`),
  `history`, and `syncbooks`. home-manager merges these onto the shared framework.
- **Host-conditional packages** via `osConfig.networking.hostName`:

```nix
{ pkgs, lib, osConfig, ... }:
let
  hostname = osConfig.networking.hostName;
in
{
  # ...abosio config...
  home.packages =
    lib.optional (hostname != "norfolk") pkgs.obs-studio
    # ++ lib.optional (hostname == "norfolk") pkgs.pong3d   # example: norfolk-only (future)
    ;
}
```

`obs-studio` moves out of the shared base into this list. On Logan
(`hostname != "norfolk"`) it is included, so Logan's resolved package set — shared
base ∪ `obs-studio` — equals today's set exactly. The `pong3d` line is a commented
placeholder demonstrating the Norfolk-only pattern; the real Norfolk-only package
is filled in by the Norfolk spec (left commented now to avoid referencing a
package that isn't installed anywhere yet).

### Note: `home.stateVersion` is per-user, not per-machine

`home.stateVersion` pins the release whose default values home-manager uses for a
given user's environment. abosio keeps `25.05` on every host so abosio's home
behaves identically wherever abosio logs in; it does not need to match a host's OS
release. jayme, a different user, will get her own `home.stateVersion` (likely
`26.05`) in `home/jayme/default.nix` when first created. This parallels — and
deliberately contrasts with — `system.stateVersion`, which is per-host
(deviation 1).

## flake.nix

Adopt the `mkHost` helper, wrapping the home-manager / sops-nix / specialArgs
boilerplate that is currently inline:

```nix
outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, home-manager, sops-nix, nixos-secrets }:
let
  system = "x86_64-linux";
  pkgs-unstable = import nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };

  mkHost = { hostname, users }:
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/${hostname}
        home-manager.nixosModules.home-manager
        sops-nix.nixosModules.sops
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit pkgs-unstable; };
          home-manager.users = users;
        }
      ];
    };
in
{
  nixosConfigurations.logan = mkHost {
    hostname = "logan";
    users = { abosio = import ./home/abosio; };
  };
  # norfolk = mkHost { ... };   # future spec
};
```

`./hosts/logan` resolves to its `default.nix` automatically.

## Order of Operations (for the implementation plan)

1. Record the baseline `toplevel` store path (path A) from the current commit.
2. Create `modules/nixos/*.nix`, `hosts/logan/`, `home/shared/*`,
   `home/abosio/default.nix`.
3. Move `hardware-configuration.nix` → `hosts/logan/hardware-configuration.nix`.
4. Rewrite `flake.nix` with `mkHost`.
5. `git add -A` (git-backed flakes ignore untracked files), then build path B.
6. Assert path A == path B.
7. Delete the now-empty originals (`configuration.nix`, `home.nix`, `kitty.nix`,
   `packages.nix`, `zsh.nix`) — only after path equality is confirmed.
8. Re-build once more post-deletion to confirm the path is still A.
9. Update `CLAUDE.md` to describe the new layout.

## Risks & Mitigations

- **Dropped option during the split.** Mitigated by the store-path equality gate —
  any dropped or changed option changes the path.
- **Untracked-file invisibility.** Git-backed flakes ignore untracked files;
  `git add -A` before every build.
- **`stateVersion` accidentally shared.** `system.stateVersion` explicitly placed
  per-host (deviation 1); `home.stateVersion` explicitly per-user.
- **`osConfig` host-branching shifts Logan's package set.** On Logan every branch
  resolves to today's set (shared base ∪ `obs-studio`), and `home.packages` builds
  a `buildEnv` keyed by the set of derivations, so the resulting path is unchanged.
  The store-path gate is the backstop if any branch is mis-written.
- **CLAUDE.md drift.** Updated as the final step so docs match the new layout.

## Documentation Updates

Update `CLAUDE.md` "File Organization" and the "Adding Configurations" sections to
reflect the `hosts/` + `modules/` + `home/<user>/` layout once the refactor is
verified.
