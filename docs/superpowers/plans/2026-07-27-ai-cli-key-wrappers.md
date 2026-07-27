# AI CLI API-Key Wrapper Scripts (`cld` / `cdx`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two Nix-managed macOS wrapper commands, `cld` and `cdx`, that resolve an `op://` 1Password reference to a real API key only at launch time (not eagerly via direnv on every `cd`), then exec the real `claude`/`codex` CLI.

**Architecture:** A new Home Manager module, `home/abosio/ai-cli-wrappers.nix`, defines a single parameterized `mkKeyWrapper` function (via `pkgs.writeShellScriptBin`) instantiated twice — once for `cld` (wraps `claude`, env vars `OP_ANTHROPIC_API_KEY`/`ANTHROPIC_API_KEY`) and once for `cdx` (wraps `codex`, env vars `OP_OPENAI_API_KEY`/`OPENAI_API_KEY`). `darwin.nix` imports the module and adds both packages to `home.packages`.

**Tech Stack:** Nix (`pkgs.writeShellScriptBin`), Bash, the `op` CLI (`op read`), Home Manager standalone (`aarch64-darwin`).

## Global Constraints

- macOS only — this module must only be imported by `home/abosio/darwin.nix`, never by `home/abosio/default.nix` (the NixOS/Linux profile) or any shared module.
- No support for `opencode`, and no directory-based key selection — the user sets `OP_ANTHROPIC_API_KEY` / `OP_OPENAI_API_KEY` themselves (each holding an `op://vault/item/field` reference, not a real secret).
- Missing/unreadable key must never hard-fail silently: always prompt `Continue without an API key? [y/N]` (default **no**) before deciding whether to launch without a key or abort.
- Never print the resolved secret value to stdout/stderr.
- Spec: `docs/superpowers/specs/2026-07-27-ai-cli-key-wrappers-design.md`.

---

### Task 1: Create the `ai-cli-wrappers.nix` module and wire it into `darwin.nix`

**Files:**
- Create: `home/abosio/ai-cli-wrappers.nix`
- Modify: `home/abosio/darwin.nix` (add import + register packages in `home.packages`)

**Interfaces:**
- Produces: `import ./ai-cli-wrappers.nix { inherit pkgs; }` returns an attrset `{ cld = <derivation>; cdx = <derivation>; }`, each a `pkgs.writeShellScriptBin` output whose `bin/<name>` is the wrapper script.

- [ ] **Step 1: Write `home/abosio/ai-cli-wrappers.nix`**

```nix
{ pkgs }:

let
  mkKeyWrapper = { name, opEnvVar, exportVar, binary }:
    pkgs.writeShellScriptBin name ''
      set -eo pipefail

      resolve_failed() {
        local msg="$1"
        shift
        echo "$msg" >&2
        read -r -p "Continue without an API key? [y/N] " reply || true
        if [[ "$reply" =~ ^[Yy]$ ]]; then
          exec ${binary} "$@"
        else
          echo "Aborting." >&2
          exit 1
        fi
      }

      ref="$(printenv "${opEnvVar}" 2>/dev/null || true)"

      if [[ -z "$ref" ]]; then
        resolve_failed "${opEnvVar} is not set." "$@"
      fi

      if key="$(op read "$ref" 2>&1)"; then
        export ${exportVar}="$key"
        exec ${binary} "$@"
      else
        resolve_failed "op read failed: $key" "$@"
      fi
    '';
in
{
  cld = mkKeyWrapper {
    name = "cld";
    opEnvVar = "OP_ANTHROPIC_API_KEY";
    exportVar = "ANTHROPIC_API_KEY";
    binary = "claude";
  };
  cdx = mkKeyWrapper {
    name = "cdx";
    opEnvVar = "OP_OPENAI_API_KEY";
    exportVar = "OPENAI_API_KEY";
    binary = "codex";
  };
}
```

Note on the `printenv "${opEnvVar}"` line: this deliberately avoids writing a literal `$` immediately before a Nix antiquotation (e.g. `$${opEnvVar}` or `''${opEnvVar}`) — both were tried and either failed to substitute or required exact escaping that's easy to get subtly wrong. Reading the value via `printenv "<name>"` needs only a single, unambiguous `${opEnvVar}` antiquotation.

- [ ] **Step 2: Wire the module into `darwin.nix`**

Open `home/abosio/darwin.nix`. Change the top of the file from:

```nix
{ pkgs, pkgs-unstable, lib, ... }:

{
  imports = [
    ../shared/vim.nix
    ../shared/zsh.nix
    ./aliases.nix
    (import ./git.nix { email = "abosio@sixfeetup.com"; })
  ];
```

to:

```nix
{ pkgs, pkgs-unstable, lib, ... }:

let
  aiCliWrappers = import ./ai-cli-wrappers.nix { inherit pkgs; };
in
{
  imports = [
    ../shared/vim.nix
    ../shared/zsh.nix
    ./aliases.nix
    (import ./git.nix { email = "abosio@sixfeetup.com"; })
  ];
```

Then change the `home.packages` list from:

```nix
  home.packages = [
    pkgs-unstable.codex
    pkgs-unstable.devenv
    pkgs.awscli2
    pkgs.bat
    pkgs.dust
    pkgs.openssl
    pkgs.eza
    pkgs.ffmpeg
    pkgs.gh
    pkgs.kubectl
    pkgs.lazygit
    pkgs.mkcert
    pkgs.mpv
    pkgs.nssTools
    pkgs.tmux
    pkgs.zoxide
    pkgs.zsh-powerlevel10k
  ];
```

to:

```nix
  home.packages = [
    pkgs-unstable.codex
    pkgs-unstable.devenv
    pkgs.awscli2
    pkgs.bat
    pkgs.dust
    pkgs.openssl
    pkgs.eza
    pkgs.ffmpeg
    pkgs.gh
    pkgs.kubectl
    pkgs.lazygit
    pkgs.mkcert
    pkgs.mpv
    pkgs.nssTools
    pkgs.tmux
    pkgs.zoxide
    pkgs.zsh-powerlevel10k
    aiCliWrappers.cld
    aiCliWrappers.cdx
  ];
```

- [ ] **Step 3: Build the activation package (does not activate anything)**

Run: `cd ~/nixos-config && nix build .#homeConfigurations.abosio.activationPackage --out-link /tmp/hm-check-result`
Expected: command exits 0, no errors. `ls /tmp/hm-check-result/home-path/bin | grep -E '^(cld|cdx)$'` prints both `cld` and `cdx`.

- [ ] **Step 4: Verify script text was generated correctly**

Run: `cat /tmp/hm-check-result/home-path/bin/cld`
Expected: matches the template from Step 1 with `${binary}` → `claude`, `${opEnvVar}` → `OP_ANTHROPIC_API_KEY`, `${exportVar}` → `ANTHROPIC_API_KEY` (no literal `${...}` left un-substituted anywhere in the output).

Run: `cat /tmp/hm-check-result/home-path/bin/cdx`
Expected: same shape with `codex` / `OP_OPENAI_API_KEY` / `OPENAI_API_KEY`.

- [ ] **Step 5: Functional test — all 4 scenarios against the built `cld` binary**

Set up isolated stub binaries (do **not** skip the `-u ANTHROPIC_API_KEY` / `env -i` isolation — without it, an already-exported `ANTHROPIC_API_KEY` in your shell leaks into the stub's output):

```bash
stubdir="$(mktemp -d)"
cat > "$stubdir/claude" <<'EOF'
#!/usr/bin/env bash
echo "claude called with args: $*"
echo "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-<unset>}"
EOF
chmod +x "$stubdir/claude"

cat > "$stubdir/op-success" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "read" ]] && echo "sk-fake-secret-123" && exit 0
EOF
chmod +x "$stubdir/op-success"

cat > "$stubdir/op-fail" <<'EOF'
#!/usr/bin/env bash
echo "[ERROR] fake failure" >&2
exit 1
EOF
chmod +x "$stubdir/op-fail"
```

Scenario A — valid ref, op succeeds:

```bash
mkdir -p "$stubdir/binA"
ln -sf "$stubdir/op-success" "$stubdir/binA/op"
ln -sf "$stubdir/claude" "$stubdir/binA/claude"
env -u ANTHROPIC_API_KEY -i PATH="$stubdir/binA:/usr/bin:/bin" \
  OP_ANTHROPIC_API_KEY="op://vault/item/field" \
  /tmp/hm-check-result/home-path/bin/cld --foo bar
```

Expected output:
```
claude called with args: --foo bar
ANTHROPIC_API_KEY=sk-fake-secret-123
```

Scenario B — unset var, answer yes:

```bash
mkdir -p "$stubdir/binB"
ln -sf "$stubdir/claude" "$stubdir/binB/claude"
echo "y" | env -u ANTHROPIC_API_KEY -i PATH="$stubdir/binB:/usr/bin:/bin" \
  /tmp/hm-check-result/home-path/bin/cld --foo bar
```

Expected output:
```
OP_ANTHROPIC_API_KEY is not set.
claude called with args: --foo bar
ANTHROPIC_API_KEY=<unset>
```

Scenario C — unset var, answer no:

```bash
echo "n" | env -u ANTHROPIC_API_KEY -i PATH="$stubdir/binB:/usr/bin:/bin" \
  /tmp/hm-check-result/home-path/bin/cld --foo bar; echo "exit code: $?"
```

Expected output:
```
OP_ANTHROPIC_API_KEY is not set.
Aborting.
exit code: 1
```
(no "claude called" line — confirms claude was never launched)

Scenario D — `op read` fails, answer yes:

```bash
mkdir -p "$stubdir/binD"
ln -sf "$stubdir/op-fail" "$stubdir/binD/op"
ln -sf "$stubdir/claude" "$stubdir/binD/claude"
echo "y" | env -u ANTHROPIC_API_KEY -i PATH="$stubdir/binD:/usr/bin:/bin" \
  OP_ANTHROPIC_API_KEY="op://vault/item/field" \
  /tmp/hm-check-result/home-path/bin/cld --foo bar
```

Expected output:
```
op read failed: [ERROR] fake failure
claude called with args: --foo bar
ANTHROPIC_API_KEY=<unset>
```

- [ ] **Step 6: Clean up test artifacts**

Run: `rm -rf "$stubdir" /tmp/hm-check-result`

- [ ] **Step 7: Commit**

```bash
cd ~/nixos-config
git add home/abosio/ai-cli-wrappers.nix home/abosio/darwin.nix
git commit -m "feat(darwin): add cld/cdx wrapper commands for on-demand 1Password key resolution"
```

---

### Task 2: Document the new commands

**Files:**
- Modify: `docs/darwin-workstation.md`

**Interfaces:**
- Consumes: nothing from Task 1's code — this is documentation only, but references the exact env var and command names from Task 1 (`cld`, `cdx`, `OP_ANTHROPIC_API_KEY`, `OP_OPENAI_API_KEY`).

- [ ] **Step 1: Add a row to the "Programs currently configured" table**

In `docs/darwin-workstation.md`, find this table (around line 67-74):

```markdown
### Programs currently configured

| Program | Module location | Notes |
|---|---|---|
| zsh | `home/shared/zsh.nix` + `home/abosio/aliases.nix` + `darwin.nix` | Framework in shared (no aliases); base aliases in aliases.nix; macOS init in darwin.nix |
| git | `home/abosio/git.nix` | abosio's identity + ignores; email per profile (work on macOS, personal on NixOS). Not for other users. |
| p10k | `darwin.nix` initContent | Theme sourced from `pkgs.zsh-powerlevel10k`; configure via `p10k configure` |
| direnv | `darwin.nix` (`programs.direnv`) | Managed by the Home Manager module (zsh integration enabled) |
```

Add one row after the `direnv` row:

```markdown
| cld / cdx | `home/abosio/ai-cli-wrappers.nix` | On-demand wrappers for `claude`/`codex` that resolve an `op://` reference from `OP_ANTHROPIC_API_KEY`/`OP_OPENAI_API_KEY` via `op read` at launch time, instead of direnv resolving it eagerly on every `cd` |
```

- [ ] **Step 2: Add a short usage section**

Immediately after the "### Shell functions" section (around line 81-83, right before "### Environment variables"), insert:

```markdown
### AI CLI key wrappers (`cld` / `cdx`)

`cld` wraps `claude`; `cdx` wraps `codex`. Each resolves an `op://` 1Password
reference into the real API key only when you run it — not eagerly on every
`cd` the way a direnv-driven `op` call would (that pattern is what caused
slow/hanging terminals after an idle period).

Set the reference (not the real secret) in `.envrc` or your shell env:

```bash
export OP_ANTHROPIC_API_KEY="op://vault/item/field"
export OP_OPENAI_API_KEY="op://vault/item/field"
```

Running `cld`/`cdx` then calls `op read` once, exports the resolved key
(`ANTHROPIC_API_KEY` / `OPENAI_API_KEY`), and execs the real CLI. If the
reference isn't set, or `op read` fails, you're prompted:
`Continue without an API key? [y/N]` — yes launches the CLI with no key
exported (falls back to its own subscription/login auth), no aborts.
```

- [ ] **Step 3: Commit**

```bash
cd ~/nixos-config
git add docs/darwin-workstation.md
git commit -m "docs(darwin): document cld/cdx AI CLI key wrappers"
```

---

### Task 3: Activate on the live machine (requires user confirmation before running)

**Files:** none (no code changes — this is the deployment step)

**Interfaces:** none

- [ ] **Step 1: Ask the user for explicit go-ahead before running this step** — it modifies the real, live Home Manager generation on this machine (reversible via `home-manager generations`, but still a real-environment change, not a sandboxed build).

- [ ] **Step 2: Switch**

Run: `cd ~/nixos-config && nix run home-manager/release-26.05 -- switch --flake .#abosio`
Expected: activation succeeds with no errors.

- [ ] **Step 3: Verify in a new shell**

Open a new terminal (or `exec zsh -l`), then run: `which cld cdx`
Expected: both resolve to paths under `/etc/profiles/per-user/abosio/bin/` or `~/.nix-profile/bin/` (wherever Home Manager links `home.packages`).

- [ ] **Step 4: Smoke-test one real invocation**

Run: `OP_ANTHROPIC_API_KEY= cld --version` (deliberately empty, to exercise the "not set" prompt path against the real binary) and answer `n` at the prompt.
Expected: prints `OP_ANTHROPIC_API_KEY is not set.` and `Aborting.`, exits 1, `claude` is never actually launched.

No commit — this task only activates already-committed config.
