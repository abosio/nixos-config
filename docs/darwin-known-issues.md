# macOS Workstation — Known Issues & TODO

Tracked rough edges in the standalone Home Manager config for the macOS workstation
(`home/abosio/darwin.nix` + the `homeConfigurations."abosio"` flake output). None
are currently breaking the build; they are fragilities to clean up.

## 1. Stable Darwin `pkgs` has no `allowUnfree` — RESOLVED (2026-06-19)

Previously the macOS home config built with `pkgs = nixpkgs.legacyPackages.${darwinSystem}`,
which uses default config (`allowUnfree = false`) — so the **stable** package set
would reject the first unfree package added (while `pkgs-unstable-darwin` already
allowed them, an inconsistency). Fixed in `flake.nix` by constructing `pkgs`
explicitly:

```nix
pkgs = import nixpkgs {
  system = darwinSystem;
  config.allowUnfree = true;
};
```

## 2. Hardcoded Homebrew OpenSSL version in `CPPFLAGS`/`LDFLAGS`

`darwin.nix` sets:

```nix
CPPFLAGS = "-I/opt/homebrew/opt/openssl@3/3.3.1/include";
LDFLAGS  = "-L/opt/homebrew/opt/openssl@3/3.3.1/lib";
```

The pinned `3.3.1` path breaks on the next `brew upgrade openssl@3` (the versioned
directory changes).

- **Recommendation (preferred): use Nix-provided OpenSSL** — reproducible and drops
  the Homebrew dependency for these flags:
  ```nix
  # add pkgs.openssl to home.packages, then:
  CPPFLAGS = "-I${pkgs.openssl.dev}/include";
  LDFLAGS  = "-L${pkgs.openssl.out}/lib";
  ```
  Verify the affected builds (Python C-extensions via pip/pyenv, node-gyp, etc.)
  are happy with Nix's OpenSSL before committing.
- **Recommendation (minimal): unpin via `brew --prefix`** — stays on Homebrew but
  removes the version pin (resolved at shell-source time):
  ```nix
  CPPFLAGS = "-I$(brew --prefix openssl@3)/include";
  LDFLAGS  = "-L$(brew --prefix openssl@3)/lib";
  ```
- **Status:** to be addressed on the workstation (it affects local dev builds, so
  verify there).

## 3. direnv ↔ p10k instant-prompt ordering (verify after the `programs.direnv` switch)

direnv was switched from a hand-written hook in `initContent` to the Home Manager
module (`programs.direnv = { enable = true; enableZshIntegration = true; }`). The
old config ran `direnv export` *before* the p10k instant prompt to avoid the
"console output during zsh initialization" warning.

- **Verify on the machine:** open a new shell, and `cd` into a directory with an
  `.envrc`. If powerlevel10k shows an instant-prompt warning about console output:
  - **Fallback:** re-add, in the `lib.mkBefore` `initContent` block (before the
    instant-prompt source), an explicit pre-prompt export:
    ```sh
    (( ${+commands[direnv]} )) && emulate zsh -c "$(direnv export zsh)"
    ```
    and set `programs.direnv.enableZshIntegration = false` so the module doesn't
    also add a hook.
- **Optional enhancement:** add `programs.direnv.nix-direnv.enable = true;` for
  cached `use nix`/`use flake` environments.
- **Status:** verify on the workstation after the next `home-manager switch`.
