# Multi-Host Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the single-host Logan NixOS config into a `hosts/` + `modules/` + `home/<user>/` layout that is forward-compatible with a future `norfolk` host and `jayme` user, without changing Logan's runtime behavior.

**Architecture:** Strangler refactor. `configuration.nix` and `home.nix` stay as the flake's entry points while settings are extracted one module at a time; the system is rebuilt after every extraction and the resulting `system.build.toplevel` store path is compared to a baseline. Only once the new layout is fully wired and verified are the original entry files moved into `hosts/logan/` and the flake repointed. Because NixOS/home-manager modules merge order-independently, moving an option verbatim into an imported module produces an identical evaluation — any accidental drop changes the store path and fails the check.

**Tech Stack:** Nix flakes, NixOS modules, home-manager (as a NixOS module), `nix build` / `nix store diff-closures`.

**Spec:** `docs/superpowers/specs/2026-06-02-multi-host-refactor-design.md`

---

## Verification Procedure (used by almost every task)

The acceptance gate for the whole refactor is: **the `toplevel` store path never changes from the baseline captured in Task 0.**

Git-backed flakes ignore untracked files, so every verification stages first with `git add -A`, then builds, then compares. The exact command block (the **VERIFY block**) is:

```bash
git add -A
nix build .#nixosConfigurations.logan.config.system.build.toplevel \
  --no-link --print-out-paths > /tmp/logan-new-path
diff <(cat /tmp/logan-baseline-path) /tmp/logan-new-path \
  && echo "✓ PATH PRESERVED" \
  || { echo "✗ PATH CHANGED — investigate:"; \
       nix store diff-closures "$(cat /tmp/logan-baseline-path)" "$(cat /tmp/logan-new-path)"; }
```

Expected output: `✓ PATH PRESERVED`.

If it prints `✗ PATH CHANGED`, the `nix store diff-closures` output shows exactly which packages/closures differ — fix the just-edited file so no option was dropped or altered, then re-run the VERIFY block before committing. Do **not** commit a task whose VERIFY block does not print `✓ PATH PRESERVED`.

**Commit convention:** this repo ends commit messages with a Co-Authored-By trailer, expressed as a second `-m` flag in every commit step.

---

## File Structure

**Created (system modules):**
- `modules/nixos/common.nix` — base every fleet machine gets (nix, locale, audio, ssh, networkmanager, avahi, zsh, nix-ld, unfree/insecure, vim, git.abosio.com host, Caddy CA)
- `modules/nixos/fonts.nix` — Fira Code + fontconfig
- `modules/nixos/desktop-gnome.nix` — X11/GDM/GNOME/xkb + gnome-terminal dconf font
- `modules/nixos/printing.nix` — CUPS + drivers + avahi.publish + Brother printer
- `modules/nixos/tailscale.nix` — tailscale
- `modules/nixos/onepassword.nix` — 1Password CLI+GUI + polkit owner
- `modules/nixos/users.nix` — `abosio` system account
- `modules/nixos/amdgpu.nix` — AMD video drivers + graphics
- `modules/nixos/syncthing.nix` — host-aware syncthing (self-filters its own hostname)

**Created (home):**
- `home/shared/kitty.nix`, `home/shared/packages.nix`, `home/shared/zsh.nix`
- `home/abosio/default.nix`

**Created (host):**
- `hosts/logan/default.nix`, `hosts/logan/hardware-configuration.nix` (moved)

**Modified:** `flake.nix` (repoint + `mkHost`), `CLAUDE.md` (layout docs).

**Removed by end (via `git mv`):** root `configuration.nix`, `home.nix`, `kitty.nix`, `packages.nix`, `zsh.nix`, `hardware-configuration.nix`.

---

## Task 0: Capture the baseline store path

**Files:** none (read-only baseline).

- [ ] **Step 1: Confirm a clean tree on the working branch**

Run: `git status --short && git branch --show-current`
Expected: no output from `git status` (clean), branch `refactor-multiple`.

- [ ] **Step 2: Build the current config and record the baseline path**

```bash
nix build .#nixosConfigurations.logan.config.system.build.toplevel \
  --no-link --print-out-paths | tee /tmp/logan-baseline-path
```
Expected: one `/nix/store/...-nixos-system-logan-...` path printed and written to `/tmp/logan-baseline-path`. This path is the gate for every later task.

- [ ] **Step 3: Sanity-check the file**

Run: `cat /tmp/logan-baseline-path`
Expected: the same single store path. (No commit — nothing changed.)

---

## Task 1: Extract `modules/nixos/common.nix`

**Files:**
- Create: `modules/nixos/common.nix`
- Modify: `configuration.nix`

- [ ] **Step 1: Create the module**

```nix
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
}
```

- [ ] **Step 2: Add the import to `configuration.nix`**

In `configuration.nix`, change the `imports` list so it reads:

```nix
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./modules/nixos/common.nix
    ];
```

- [ ] **Step 3: Delete the now-moved settings from `configuration.nix`**

Remove these blocks from `configuration.nix` (they now live in `common.nix`):
- `nix.settings.experimental-features = [ "nix-command" "flakes" ];` (the line above `imports`)
- `system.autoUpgrade.enable` and `system.autoUpgrade.allowReboot` lines
- the `networking.extraHosts = '' ... '';` block
- `networking.networkmanager.enable = true;`
- the `services.avahi = { enable = true; nssmdns4 = true; };` block
- `time.timeZone = "America/New_York";`
- `i18n.defaultLocale` and the whole `i18n.extraLocaleSettings = { ... };` block
- the `services.pulseaudio.enable = false;`, `security.rtkit.enable = true;`, and `services.pipewire = { ... };` block
- `programs.zsh.enable = true;`
- `programs.nix-ld.enable = true;`
- the `environment.systemPackages = with pkgs; [ ... pkgs.vim ];` block
- the `security.pki.certificateFiles = [ ... ];` block
- `nixpkgs.config.allowUnfree = true;` and the `nixpkgs.config.permittedInsecurePackages = [ ... ];` block

Leave in `configuration.nix` for now: bootloader, `networking.hostName`, X11/GNOME/AMD/printing/users/tailscale/syncthing/fonts/dconf/1password, `system.stateVersion`, `/mnt/pi`. (Those move in later tasks.)

- [ ] **Step 4: Verify path preserved**

Run the **VERIFY block** (see top of plan).
Expected: `✓ PATH PRESERVED`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: extract common.nix system module" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Extract `modules/nixos/fonts.nix`

**Files:**
- Create: `modules/nixos/fonts.nix`
- Modify: `configuration.nix`

- [ ] **Step 1: Create the module**

```nix
# modules/nixos/fonts.nix
{ pkgs, ... }:

{
  fonts = {
    packages = with pkgs; [
      fira-code
    ];
    fontconfig.enable = true;
    fontDir.enable = true;
  };
}
```

- [ ] **Step 2: Add the import**

Add `./modules/nixos/fonts.nix` to the `imports` list in `configuration.nix`.

- [ ] **Step 3: Delete the moved settings**

Remove the entire `fonts = { packages = with pkgs; [ fira-code ]; fontconfig.enable = true; fontDir.enable = true; };` block from `configuration.nix`.

- [ ] **Step 4: Verify path preserved**

Run the **VERIFY block**. Expected: `✓ PATH PRESERVED`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: extract fonts.nix system module" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Extract `modules/nixos/desktop-gnome.nix`

**Files:**
- Create: `modules/nixos/desktop-gnome.nix`
- Modify: `configuration.nix`

- [ ] **Step 1: Create the module**

```nix
# modules/nixos/desktop-gnome.nix
{ ... }:

{
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
}
```

- [ ] **Step 2: Add the import**

Add `./modules/nixos/desktop-gnome.nix` to the `imports` list.

- [ ] **Step 3: Delete the moved settings**

Remove from `configuration.nix`:
- `services.xserver.enable = true;`
- `services.xserver.displayManager.gdm.enable = true;` and `services.xserver.desktopManager.gnome.enable = true;`
- the `services.xserver.xkb = { layout = "us"; variant = ""; };` block
- the whole `programs.dconf = { ... };` block

Do **not** remove `services.xserver.videoDrivers = [ "amdgpu" ];` or the `hardware.graphics.*` lines — those move in Task 8.

- [ ] **Step 4: Verify path preserved**

Run the **VERIFY block**. Expected: `✓ PATH PRESERVED`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: extract desktop-gnome.nix system module" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Extract `modules/nixos/printing.nix`

**Files:**
- Create: `modules/nixos/printing.nix`
- Modify: `configuration.nix`

- [ ] **Step 1: Create the module**

```nix
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
```

- [ ] **Step 2: Add the import**

Add `./modules/nixos/printing.nix` to the `imports` list.

- [ ] **Step 3: Delete the moved settings**

Remove from `configuration.nix`: the `services.printing.enable` line, the `services.printing.drivers = with pkgs; [ ... ];` block, the two `services.avahi.publish.*` lines, and the whole `hardware.printers.ensurePrinters = [{ ... }];` block.

- [ ] **Step 4: Verify path preserved**

Run the **VERIFY block**. Expected: `✓ PATH PRESERVED`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: extract printing.nix system module" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: Extract `modules/nixos/tailscale.nix`

**Files:**
- Create: `modules/nixos/tailscale.nix`
- Modify: `configuration.nix`

- [ ] **Step 1: Create the module**

```nix
# modules/nixos/tailscale.nix
{ ... }:

{
  services.tailscale.enable = true;
}
```

- [ ] **Step 2: Add the import**

Add `./modules/nixos/tailscale.nix` to the `imports` list.

- [ ] **Step 3: Delete the moved setting**

Remove `services.tailscale.enable = true;` from `configuration.nix`.

- [ ] **Step 4: Verify path preserved**

Run the **VERIFY block**. Expected: `✓ PATH PRESERVED`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: extract tailscale.nix system module" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: Extract `modules/nixos/onepassword.nix`

**Files:**
- Create: `modules/nixos/onepassword.nix`
- Modify: `configuration.nix`

- [ ] **Step 1: Create the module**

```nix
# modules/nixos/onepassword.nix
{ ... }:

{
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    # Certain features, including CLI integration and system authentication support,
    # require enabling PolKit integration on some desktop environments (e.g. Plasma).
    polkitPolicyOwners = [ "abosio" ];
  };
}
```

- [ ] **Step 2: Add the import**

Add `./modules/nixos/onepassword.nix` to the `imports` list.

- [ ] **Step 3: Delete the moved settings**

Remove from `configuration.nix`: `programs._1password.enable = true;` and the whole `programs._1password-gui = { ... };` block.

- [ ] **Step 4: Verify path preserved**

Run the **VERIFY block**. Expected: `✓ PATH PRESERVED`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: extract onepassword.nix system module" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: Extract `modules/nixos/users.nix`

**Files:**
- Create: `modules/nixos/users.nix`
- Modify: `configuration.nix`

- [ ] **Step 1: Create the module**

```nix
# modules/nixos/users.nix
{ pkgs, ... }:

{
  users.users.abosio = {
    isNormalUser = true;
    description = "Anthony Bosio";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.zsh;
  };
}
```

Note: the original `users.users.abosio` has an empty `packages = with pkgs; [ ];` list (only a commented-out `thunderbird`). An empty package list is the default, so omitting it is behavior-identical; the VERIFY block confirms this.

- [ ] **Step 2: Add the import**

Add `./modules/nixos/users.nix` to the `imports` list.

- [ ] **Step 3: Delete the moved settings**

Remove the whole `users.users.abosio = { ... };` block from `configuration.nix` (including its `packages = with pkgs; [ ];` sub-list).

- [ ] **Step 4: Verify path preserved**

Run the **VERIFY block**. Expected: `✓ PATH PRESERVED`.

(If it reports a change, the empty-packages omission is the prime suspect — add `packages = with pkgs; [ ];` back into the module and re-verify.)

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: extract users.nix system module" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 8: Extract `modules/nixos/amdgpu.nix`

**Files:**
- Create: `modules/nixos/amdgpu.nix`
- Modify: `configuration.nix`

- [ ] **Step 1: Create the module**

```nix
# modules/nixos/amdgpu.nix
{ ... }:

{
  # Configure AMD GPU drivers for hybrid graphics (RX 7600M + Radeon 680M)
  services.xserver.videoDrivers = [ "amdgpu" ];

  # Enable hardware acceleration for AMD GPUs
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
}
```

- [ ] **Step 2: Add the import**

Add `./modules/nixos/amdgpu.nix` to the `imports` list.

- [ ] **Step 3: Delete the moved settings**

Remove from `configuration.nix`: `services.xserver.videoDrivers = [ "amdgpu" ];`, `hardware.graphics.enable = true;`, and `hardware.graphics.enable32Bit = true;`.

- [ ] **Step 4: Verify path preserved**

Run the **VERIFY block**. Expected: `✓ PATH PRESERVED`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: extract amdgpu.nix system module" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 9: Extract `modules/nixos/syncthing.nix` (host-aware)

**Files:**
- Create: `modules/nixos/syncthing.nix`
- Modify: `configuration.nix`

- [ ] **Step 1: Create the module**

```nix
# modules/nixos/syncthing.nix
# Host-aware: each host syncs with every *other* device, never itself.
# Today the secrets file holds only gotham + MBP, so filtering out "logan"
# is a no-op and Logan's device set is unchanged.
{ config, inputs, lib, ... }:

let
  allDevices = import "${inputs.nixos-secrets}/syncthing-devices.nix";
  devices = lib.filterAttrs (name: _: name != config.networking.hostName) allDevices;
in
{
  services.syncthing = {
    enable = true;
    user = "abosio";
    openDefaultPorts = true; # Open ports in the firewall for Syncthing
    dataDir = "/home/abosio/.local/share/syncthing";
    configDir = "/home/abosio/.config/syncthing";
    settings = {
      devices = devices;
    };
  };
}
```

- [ ] **Step 2: Add the import**

Add `./modules/nixos/syncthing.nix` to the `imports` list.

- [ ] **Step 3: Delete the moved settings**

Remove the whole `services.syncthing = { ... };` block from `configuration.nix`.

- [ ] **Step 4: Verify path preserved**

Run the **VERIFY block**. Expected: `✓ PATH PRESERVED`.

This is the key behavior-preservation check for the host-aware filter: if `gotham`/`MBP` were accidentally dropped, the syncthing service config — and the closure — would differ.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: extract host-aware syncthing.nix system module" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 10: Move kitty into `home/shared/`

**Files:**
- Move: `kitty.nix` → `home/shared/kitty.nix`
- Modify: `home.nix`

- [ ] **Step 1: Move the file with git**

```bash
mkdir -p home/shared
git mv kitty.nix home/shared/kitty.nix
```

(Contents are unchanged. For reference, `home/shared/kitty.nix` is:)

```nix
{ ... }:

{
  # Setup kitty terminal
  programs.kitty = {
    enable = true;
    shellIntegration.enableZshIntegration = true;
    font = {
      name = "Fira Code";
      size = 14;
    };
    themeFile = "Nord";
  };
}
```

- [ ] **Step 2: Update the import in `home.nix`**

In `home.nix`, change `./kitty.nix` in the `imports` list to `./home/shared/kitty.nix`.

- [ ] **Step 3: Verify path preserved**

Run the **VERIFY block**. Expected: `✓ PATH PRESERVED`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: move kitty.nix to home/shared" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 11: Move zsh framework into `home/shared/`, aliases to `home.nix`

The shared zsh module keeps only the framework; **all** `shellAliases` move to the user config (they are abosio-specific).

**Files:**
- Move: `zsh.nix` → `home/shared/zsh.nix`
- Modify: `home/shared/zsh.nix` (drop aliases), `home.nix` (add aliases)

- [ ] **Step 1: Move the file with git**

```bash
git mv zsh.nix home/shared/zsh.nix
```

- [ ] **Step 2: Remove the `shellAliases` block from `home/shared/zsh.nix`**

Delete the entire `shellAliases = { ... };` attribute (the navigation/convenience/safety/history/syncbooks block) from `home/shared/zsh.nix`. The file's `programs.zsh` should retain `enable`, `enableCompletion`, `history`, `sessionVariables`, `syntaxHighlighting`, `zplug`, and `initContent`. Result:

```nix
{ config, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    history = {
      size = 1000000;
      path = "${config.xdg.dataHome}/zsh/history";
    };
    sessionVariables = {
      EDITOR = "vim";
      TERMINAL = "kitty";
      BROWSER = "firefox";
      TERM = "xterm-256color";
    };
    syntaxHighlighting.enable = true;

    # Zsh Plugin Manager
    zplug = {
      enable = true;
      plugins = [
        { name = "zsh-users/zsh-autosuggestions"; }
        { name = "zsh-users/zsh-syntax-highlighting"; }
        { name = "zap-zsh/fzf"; }
        { name = "zap-zsh/exa"; }
      ];
    };

    # Extra setup and keybindings
    initContent = ''
      PROMPT_EOL_MARK=\'\'
      eval "$(zoxide init zsh)"

      setopt completeinword NO_flowcontrol NO_listbeep NO_singlelinezle
      autoload -Uz compinit
      compinit

      # keybinds
      bindkey '^ ' autosuggest-accept
      bindkey -v
      bindkey '^R' history-incremental-search-backward
    '';
  };
}
```

- [ ] **Step 3: Add the aliases (and the moved import) to `home.nix`**

In `home.nix`, change the `imports` entry `./zsh.nix` to `./home/shared/zsh.nix`, then add this `programs.zsh` block to the `home.nix` body (home-manager merges it onto the shared framework):

```nix
  programs.zsh.shellAliases = {
    # Navigation
    ls = "eza";
    ll = "eza -l";
    la = "eza -la";

    # Convenience
    grep = "grep --color=auto";
    cat = "bat -pp"; # A better 'cat'

    # Safety
    cp = "cp -i";
    mv = "mv -i";
    rm = "rm -i";

    # show history from first entry
    history = "history 1";

    # Sync
    syncbooks = "rsync -avh --delete  '/home/abosio/Sync/Calibre Library/' /mnt/pi/services/calibre/library/";
  };
```

- [ ] **Step 4: Verify path preserved**

Run the **VERIFY block**. Expected: `✓ PATH PRESERVED`.

The generated `.zshrc` is built from merged options; identical merged values produce an identical file and closure.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: split zsh framework (shared) from aliases (abosio)" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 12: Move packages into `home/shared/`, scaffold host-conditional obs

`obs-studio` becomes host-conditional (excluded on `norfolk`); on Logan it is still included, so the resolved package set is unchanged.

**Files:**
- Move: `packages.nix` → `home/shared/packages.nix`
- Modify: `home/shared/packages.nix` (drop obs), `home.nix` (add obs conditional + args)

- [ ] **Step 1: Move the file with git**

```bash
git mv packages.nix home/shared/packages.nix
```

- [ ] **Step 2: Remove `obs-studio` from `home/shared/packages.nix`**

Delete the line `pkgs.obs-studio` from the `home.packages` list in `home/shared/packages.nix`. Everything else stays. Result:

```nix
{ pkgs, pkgs-unstable, ... }:

{
  # Packages installed for your user
  home.packages = [
    pkgs-unstable.librepods
    pkgs.age
    pkgs.bat
    pkgs.calibre
    pkgs.claude-code
    pkgs.cliphist
    pkgs.docker
    pkgs.eza
    pkgs.fira-code
    pkgs.git
    pkgs.joplin-desktop
    pkgs.libreoffice
    pkgs.logseq
    pkgs.losslesscut-bin
    pkgs.signal-desktop
    pkgs.slack
    pkgs.sops
    pkgs.ssh-to-age
    pkgs.syncthing
    pkgs.tigervnc
    pkgs.uv
    pkgs.tor-browser
    pkgs.vivaldi
    pkgs.vlc
    pkgs-unstable.vscode
    pkgs.wl-clipboard
    pkgs.zoom-us
    pkgs.zoxide
  ];
}
```

- [ ] **Step 3: Add the host-conditional package to `home.nix`**

In `home.nix`, update the argument set on the first line from `{ pkgs, ... }:` to `{ pkgs, lib, osConfig, ... }:`, then add this block to the body:

```nix
  # Host-specific packages for this user. obs-studio everywhere except norfolk;
  # the commented line shows where a norfolk-only package would go later.
  home.packages =
    lib.optional (osConfig.networking.hostName != "norfolk") pkgs.obs-studio
    # ++ lib.optional (osConfig.networking.hostName == "norfolk") pkgs.pong3d
    ;
```

(`home.packages` set both here and in the shared module is merged by home-manager, so Logan resolves to the shared list ∪ `obs-studio` = the original set.)

- [ ] **Step 4: Verify behavior preserved (NOTE: path intentionally changes here)**

Unlike every other task, this one **changes the `toplevel` store path** — and that is expected. Re-adding `obs-studio` through a separate module moves it from mid-list to the end of the merged `home.packages`, and a `buildEnv` derivation's hash is sensitive to its `paths` list order. The *closure* (the set of store paths) is unchanged, so the system is behaviorally identical.

Verify with diff-closures emptiness instead of path identity:

```bash
git add -A
nix build .#nixosConfigurations.logan.config.system.build.toplevel \
  --no-link --print-out-paths > /tmp/logan-new-path
echo "--- diff-closures (MUST be empty = behavior identical) ---"
nix store diff-closures "$(cat /tmp/logan-baseline-path)" "$(cat /tmp/logan-new-path)"
```
Expected: the diff-closures output is **empty** (no added/removed/changed packages). If anything is listed, an option was dropped — STOP and report BLOCKED.

Then re-baseline so the remaining tasks verify against this new path:
```bash
cp /tmp/logan-new-path /tmp/logan-baseline-path
echo "re-baselined to: $(cat /tmp/logan-baseline-path)"
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: move packages to home/shared, scaffold host-conditional obs"
```

---

## Task 13: Turn `home.nix` into `home/abosio/default.nix` and repoint the flake

At this point `home.nix` imports `./home/shared/*` and contains exactly abosio's config (plus the aliases and obs conditional added above). Move it into place.

**Files:**
- Move: `home.nix` → `home/abosio/default.nix`
- Modify: `home/abosio/default.nix` (fix relative imports), `flake.nix` (repoint user)

- [ ] **Step 1: Move the file with git**

```bash
mkdir -p home/abosio
git mv home.nix home/abosio/default.nix
```

- [ ] **Step 2: Fix the relative import paths**

In `home/abosio/default.nix`, the `imports` list now sits one directory deeper. Change:
- `./home/shared/kitty.nix` → `../shared/kitty.nix`
- `./home/shared/packages.nix` → `../shared/packages.nix`
- `./home/shared/zsh.nix` → `../shared/zsh.nix`

- [ ] **Step 3: Repoint the flake's user import**

In `flake.nix`, change `home-manager.users.abosio = import ./home.nix;` to `home-manager.users.abosio = import ./home/abosio;`.

- [ ] **Step 4: Verify path preserved**

Run the **VERIFY block**. Expected: `✓ PATH PRESERVED`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: move home.nix to home/abosio/default.nix" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 14: Move the hardware configuration into `hosts/logan/`

**Files:**
- Move: `hardware-configuration.nix` → `hosts/logan/hardware-configuration.nix`
- Modify: `configuration.nix` (fix hardware import path)

- [ ] **Step 1: Move the file with git**

```bash
mkdir -p hosts/logan
git mv hardware-configuration.nix hosts/logan/hardware-configuration.nix
```

(Do not edit its contents — it is machine-generated.)

- [ ] **Step 2: Fix the import path in `configuration.nix`**

In `configuration.nix`, change `./hardware-configuration.nix` in the `imports` list to `./hosts/logan/hardware-configuration.nix`. Leave the `./modules/nixos/*.nix` import paths as-is for now (configuration.nix is still at the repo root).

- [ ] **Step 3: Verify path preserved**

Run the **VERIFY block**. Expected: `✓ PATH PRESERVED`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: move hardware-configuration.nix to hosts/logan" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 15: Turn `configuration.nix` into `hosts/logan/default.nix`

`configuration.nix` now holds only Logan-specific settings plus the module import list. Move it into the host directory and repoint the flake.

**Files:**
- Move: `configuration.nix` → `hosts/logan/default.nix`
- Modify: `hosts/logan/default.nix` (fix relative paths, clean header), `flake.nix` (repoint module)

- [ ] **Step 1: Move the file with git**

```bash
git mv configuration.nix hosts/logan/default.nix
```

- [ ] **Step 2: Rewrite the moved file to fix paths and header**

Replace the full contents of `hosts/logan/default.nix` with the following (the module import paths gain `../../`, the hardware path loses its prefix, and the now-unused `inputs, config, pkgs` header arguments are dropped). Keep only the Logan-specific settings:

```nix
# hosts/logan/default.nix
{ ... }:

{
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

  networking.hostName = "logan";

  # Bootloader (Logan is UEFI / systemd-boot).
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Logan-specific NFS mount to the Raspberry Pi 5.
  fileSystems."/mnt/pi" = {
    device = "raspberrypi5.local:/home/abosio";
    fsType = "nfs";
    options = [ "x-systemd.automount" "noauto" "_netdev" ];
  };

  # First-install release marker for THIS machine (per-host, never bumped lightly).
  system.stateVersion = "25.05";
}
```

Confirm nothing else remains: if your slimmed `configuration.nix` still contained any option not listed above, it was missed by an earlier task — stop and move it to its proper module before continuing.

- [ ] **Step 3: Repoint the flake module**

In `flake.nix`, change the module entry `./configuration.nix` to `./hosts/logan`.

- [ ] **Step 4: Verify path preserved**

Run the **VERIFY block**. Expected: `✓ PATH PRESERVED`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: move configuration.nix to hosts/logan/default.nix" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 16: Adopt the `mkHost` helper in `flake.nix`

Wrap the per-host home-manager / sops / specialArgs boilerplate in a helper so adding `norfolk` later is a few lines. This reorganizes the flake without changing what is evaluated.

**Files:**
- Modify: `flake.nix`

- [ ] **Step 1: Rewrite the `outputs` function**

Replace the entire `outputs = ...` block in `flake.nix` with:

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

        specialArgs = {
          inherit inputs;
        };

        modules = [
          ./hosts/${hostname}
          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              inherit pkgs-unstable;
            };
            home-manager.users = users;
          }
        ];
      };
  in
  {
    nixosConfigurations = {
      logan = mkHost {
        hostname = "logan";
        users = {
          abosio = import ./home/abosio;
        };
      };

      # Future host (separate spec):
      # norfolk = mkHost {
      #   hostname = "norfolk";
      #   users = {
      #     abosio = import ./home/abosio;
      #     jayme = import ./home/jayme;
      #   };
      # };
    };
  };
```

Leave the `description` and `inputs` blocks of `flake.nix` unchanged.

- [ ] **Step 2: Verify path preserved**

Run the **VERIFY block**. Expected: `✓ PATH PRESERVED`.

Module-list order and lifting `pkgs-unstable` into a `let` binding do not change evaluation, so the path must still match.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "refactor: add mkHost helper to flake for multi-host support" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 17: Update `CLAUDE.md` and do the final verification

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update the File Organization section**

In `CLAUDE.md`, replace the `### File Organization` code block with the new layout:

```text
flake.nix                       # Entry point - mkHost helper, declares hosts
├── hosts/
│   └── logan/
│       ├── default.nix         # Logan-specific settings + module imports
│       └── hardware-configuration.nix  # Auto-generated (DO NOT EDIT)
├── modules/nixos/              # Reusable system modules
│   ├── common.nix              # Base every machine gets
│   ├── fonts.nix
│   ├── desktop-gnome.nix
│   ├── printing.nix
│   ├── tailscale.nix
│   ├── onepassword.nix
│   ├── users.nix
│   ├── amdgpu.nix
│   └── syncthing.nix           # Host-aware (filters out own hostname)
├── home/
│   ├── shared/                 # Cross-user home-manager modules
│   │   ├── kitty.nix
│   │   ├── packages.nix
│   │   └── zsh.nix             # Framework only (aliases live per-user)
│   └── abosio/
│       └── default.nix         # abosio's home-manager config
└── docs/                       # Detailed documentation
```

- [ ] **Step 2: Fix stale path references in `CLAUDE.md`**

Update these references in `CLAUDE.md` so they point at the new locations:
- "Adding User Packages" → edit `home/shared/packages.nix`
- "Adding System Services" / printers → edit `hosts/logan/default.nix` or the relevant `modules/nixos/*.nix`
- "Adding Shell Aliases" → abosio's aliases live in `home/abosio/default.nix`; the zsh framework is `home/shared/zsh.nix`
- "Modifying Terminal Appearance" → edit `home/shared/kitty.nix`
- Note that `hosts/logan/hardware-configuration.nix` is the auto-generated file (regenerate with `sudo nixos-generate-config --show-hardware-config > hosts/logan/hardware-configuration.nix`)
- Update the flake-inputs version note from `nixos-25.05` to `nixos-26.05` and `release-25.05` to `release-26.05`

- [ ] **Step 3: Final path verification**

Run the **VERIFY block** one last time. Expected: `✓ PATH PRESERVED`.

- [ ] **Step 4: Confirm the tree is fully migrated**

Run: `ls configuration.nix home.nix kitty.nix packages.nix zsh.nix hardware-configuration.nix 2>&1`
Expected: every one reports "No such file or directory" (all originals have been moved).

Run: `git status --short`
Expected: only the `CLAUDE.md` modification is uncommitted.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "docs: update CLAUDE.md for multi-host layout" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 6 (optional, user-run): Activate**

The refactor is build-verified identical. To activate the (identical) generation:
```bash
sudo nixos-rebuild switch --flake .#logan
```
This is the user's call and is not required to prove the refactor correct — path equality already proves the system is unchanged.

---

## Done

After Task 17: Logan is fully described by `hosts/logan/` + `modules/nixos/` + `home/abosio/` + `home/shared/`, the flake uses `mkHost`, and every step proved the `toplevel` store path never moved from the Task 0 baseline. Adding `norfolk` + `jayme` (uncommenting the flake block, creating `hosts/norfolk/`, `home/jayme/`, and `modules/nixos/nvidia.nix`) is the subject of a future spec.
