# notion-cli

[notion-cli](https://github.com/4ier/notion-cli) is not in nixpkgs, so this repo
packages it from source in [pkgs/notion-cli/default.nix](../pkgs/notion-cli/default.nix)
and adds it to abosio's darwin profile in
[home/abosio/darwin.nix](../home/abosio/darwin.nix).

Upstream is a Go program built with goreleaser. The binary is named `notion`,
not `notion-cli`.

## Updating to a new version

1. Find the new tag:

   ```bash
   curl -sSL https://api.github.com/repos/4ier/notion-cli/tags | grep '"name"' | head
   ```

2. Bump `version` in `pkgs/notion-cli/default.nix` and get the new source hash:

   ```bash
   nix flake prefetch --json github:4ier/notion-cli/v<version> | jq -r .hash
   ```

   Put that in `src.hash`.

3. Reset `vendorHash` to `lib.fakeHash`, build, and copy the `got:` hash back in.
   Skipping this step is fine only if upstream's `go.mod`/`go.sum` are unchanged —
   otherwise the build fails with a hash mismatch that tells you the right value.

   ```bash
   nix build --no-link .#homeConfigurations.abosio.activationPackage
   ```

4. Activate and check:

   ```bash
   home-manager switch --flake .#abosio
   notion --version
   ```

New files must be `git add`ed before `nix build` sees them — flakes only read
tracked files.

## Notes

- Little Snitch must allow `proxy.golang.org` (and `go.googlesource.com` for the
  `golang.org/x/*` modules) while the `-go-modules` fetch runs, or the build
  fails with `i/o timeout` on module downloads. This only happens when
  `vendorHash` changes; otherwise the vendor dir comes from the Nix store.
- `buildGoModule` runs upstream's `go test ./...` during the build, so a failing
  test suite blocks the update.
