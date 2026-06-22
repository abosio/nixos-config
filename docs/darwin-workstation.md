# macOS Workstation (Home Manager)

This document covers managing the macOS workstation via standalone Home Manager. Unlike the NixOS hosts, there is no system-level Nix configuration here — Home Manager manages user packages and dotfiles only.

## Key Files

| File | Purpose |
|---|---|
| `flake.nix` | Declares `homeConfigurations."abosio"` for `aarch64-darwin` |
| `home/abosio/darwin.nix` | macOS entry point: packages, env vars, zsh config |
| `home/shared/zsh.nix` | Shared zsh **framework only** — no aliases (all hosts, incl. macOS) |
| `home/abosio/aliases.nix` | abosio's base shell aliases (all of abosio's profiles) |
| `home/abosio/git.nix` | abosio's git identity + ignores; email set per profile (abosio only) |

## Applying Changes

```bash
cd ~/nixos-config
nix run home-manager/release-26.05 -- switch --flake .#abosio
```

After a successful switch, changes take effect in new shell sessions. Open a new terminal to pick up zsh changes.

## Adding Packages

### macOS-only packages

Edit `home/abosio/darwin.nix` under `home.packages`:

```nix
home.packages = [
  pkgs.some-package
  pkgs-unstable.some-newer-package  # from nixpkgs-unstable
];
```

### Packages on the NixOS hosts (not the Mac)

`home/shared/packages.nix` is abosio's package set for the **NixOS hosts only** — it is *not* imported by the macOS config (it holds Linux GUI apps like `vivaldi`, `signal-desktop`, `tigervnc`). There is **no auto-shared package list** between macOS and Linux: put macOS packages in `darwin.nix` and Linux packages in `home/shared/packages.nix`. To have a package on both, add it in both places (check it builds on Darwin first).

### Finding packages

```bash
# Search nixpkgs
nix search nixpkgs some-package

# Check if a package is available on Darwin before adding
nix eval nixpkgs#some-package.meta.platforms
```

## Managing Program Configuration

Home Manager has first-class modules for many programs. Prefer `programs.X` over managing config files manually.

### Adding a new program module

Add to `darwin.nix` (macOS-only) or create a new file in `home/shared/` and import it:

```nix
# in darwin.nix or a new home/shared/foo.nix
programs.foo = {
  enable = true;
  settings = { ... };
};
```

### Programs currently configured

| Program | Module location | Notes |
|---|---|---|
| zsh | `home/shared/zsh.nix` + `home/abosio/aliases.nix` + `darwin.nix` | Framework in shared (no aliases); base aliases in aliases.nix; macOS init in darwin.nix |
| git | `home/abosio/git.nix` | abosio's identity + ignores; email per profile (work on macOS, personal on NixOS). Not for other users. |
| p10k | `darwin.nix` initContent | Theme sourced from `pkgs.zsh-powerlevel10k`; configure via `p10k configure` |
| direnv | `darwin.nix` (`programs.direnv`) | Managed by the Home Manager module (zsh integration enabled) |

### Shell aliases

- **All of abosio's machines:** Add to `home/abosio/aliases.nix` (imported by both the NixOS and macOS profiles). Do **not** add aliases to `home/shared/zsh.nix` — it is framework-only and is imported by other users (e.g. `jbosio`).
- **macOS-only:** Add to `programs.zsh.shellAliases` in `darwin.nix`, or as `alias foo=...` in the `initContent` block for aliases with complex quoting

### Shell functions

Add to the `lib.mkAfter` `initContent` block in `darwin.nix`. Example of the existing `shrink-video` function.

### Environment variables

- `home.sessionVariables` in `darwin.nix` — written to `~/.zshenv`, available in all sessions
- `home.sessionPath` in `darwin.nix` — appended to `PATH`

## Node / npm

Global node is provided by `pkgs.nodejs` in `darwin.nix`. Per-project Node versions are handled by devenv.

Global npm packages install to `~/.npm-global` (set via `NPM_CONFIG_PREFIX` in `home.sessionVariables`):

```bash
npm install -g some-package   # installs to ~/.npm-global/bin/
npm list -g --depth=0         # list installed global packages
```

`~/.npm-global/bin` is in `home.sessionPath`, so binaries are available without extra configuration.

## devenv (per-project environments)

devenv is installed via `pkgs-unstable.devenv` in `darwin.nix`. Use it for per-project Python, Node, or other language versions:

```bash
cd my-project
devenv init          # create devenv.nix
devenv shell         # enter the environment
```

With direnv + `use devenv` in `.envrc`, the environment activates automatically on `cd`. Note: aliases defined in `enterShell` are only available when using `devenv shell` directly, not via direnv.

## Updating nixpkgs

```bash
cd ~/nixos-config

# Update all inputs (nixpkgs stable + unstable, home-manager, etc.)
nix flake update

# Update only a specific input
nix flake update nixpkgs
nix flake update nixpkgs-unstable

# Then apply
nix run home-manager/release-26.05 -- switch --flake .#abosio
```

## Useful Commands

```bash
# List all Home Manager generations
home-manager generations

# Roll back to previous generation
home-manager generations | head -2
# then activate the previous one:
/nix/store/<prev-generation-path>/activate

# See what HM manages (all symlinks in ~)
home-manager packages

# Check what changed between current and a new build (dry run)
nix build ~/nixos-config#homeConfigurations.abosio.activationPackage --dry-run

# See the generated .zshrc
cat ~/.zshrc

# Free up disk space (remove old generations)
nix-collect-garbage --delete-older-than 30d
home-manager expire-generations "-30 days"
```

## Current Tool Notes

### mise

mise is temporarily active (`# TODO: remove when related project wraps up` in `darwin.nix`). Once the project wraps up, remove the `eval "$(~/.local/bin/mise activate zsh)"` line from the `lib.mkAfter` initContent block in `darwin.nix`.

### pyenv

pyenv is still managed outside of Nix (invoked from `darwin.nix` initContent, skipped inside devenv/nix shell via `$IN_NIX_SHELL` guard). It can be migrated to `programs.pyenv` or replaced with devenv's `languages.python` on a per-project basis when convenient.

### Homebrew

Homebrew is still present and initialized in the zsh config (the `eval "$(/opt/homebrew/bin/brew shellenv)"` block). It is not managed by Nix. Packages that are available in nixpkgs should be migrated to `darwin.nix` over time; `brew list` shows what's currently installed via Homebrew.

## Managed Files

Home Manager owns the following files (symlinks into the Nix store — do not edit directly):

| File | Description |
|---|---|
| `~/.zshrc` | Main shell config |
| `~/.zshenv` | Session variables (from `home.sessionVariables`) |
| `~/.config/git/config` | Git configuration |
| `~/.config/git/ignore` | Global gitignore |
