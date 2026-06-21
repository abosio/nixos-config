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

## 2. Hardcoded Homebrew OpenSSL version in `CPPFLAGS`/`LDFLAGS` — RESOLVED (2026-06-21)

Previously `darwin.nix` pinned an explicit Homebrew path that broke on `brew upgrade openssl@3`.
Fixed by adding `pkgs.openssl` to `home.packages` and switching to Nix-store paths:

```nix
CPPFLAGS = "-I${pkgs.openssl.dev}/include";
LDFLAGS  = "-L${pkgs.openssl.out}/lib";
```

## 3. direnv ↔ p10k instant-prompt ordering — RESOLVED (2026-06-21)

After switching to `programs.direnv`, no instant-prompt warning observed. The HM module
places the hook correctly relative to p10k. No fallback needed.
