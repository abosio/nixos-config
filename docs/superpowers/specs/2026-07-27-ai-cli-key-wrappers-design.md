# AI CLI API-Key Wrapper Scripts (`cld` / `cdx`) — Design

**Date:** 2026-07-27
**Status:** Approved for planning
**Scope:** macOS workstation only (`home/abosio/darwin.nix`), not the NixOS hosts.

## Goal

Replace eager, direnv-driven 1Password lookups with two on-demand wrapper
commands, `cld` (Claude Code) and `cdx` (Codex), that resolve an `op://`
reference to a real API key only at launch time — not on every `cd`.

## Problem

Loading API keys via direnv (`.envrc` calling into 1Password) on every
directory change is slow, and the first invocation after some unknown idle
period hangs the terminal badly enough that the terminal has to be closed and
reopened. The fix is to stop doing the 1Password lookup at `cd` time
entirely, and only do it when actually launching an AI CLI.

## Non-goals

- No support for `opencode` (only `claude` and `codex`).
- No directory-based key selection (unlike the SixFeetUp/OpenCode reference
  script, which branches on client folder path). The user sets the relevant
  `OP_*` env var themselves, per project or globally.
- Not used on the NixOS hosts (logan/norfolk) — Linux key handling is out of
  scope for this change.

## Design

### Nix integration

New module `home/abosio/ai-cli-wrappers.nix`, imported only by
`home/abosio/darwin.nix`. It defines two packages via
`pkgs.writeShellScriptBin` and adds them to `home.packages`. Both scripts
share a common shell function for the resolve/prompt logic, parameterized by:

| | `cld` | `cdx` |
|---|---|---|
| Reference env var | `OP_ANTHROPIC_API_KEY` | `OP_OPENAI_API_KEY` |
| Exported real key | `ANTHROPIC_API_KEY` | `OPENAI_API_KEY` |
| Wrapped binary | `claude` | `codex` |

Both `claude` and `codex` are already resolvable on `$PATH` (via
`~/.local/bin` and the Nix profile respectively), so the wrappers use
distinct names (`cld`/`cdx`) and `exec` the real binary by name — no PATH
shadowing or `command claude` tricks needed.

### Runtime flow (identical shape for both commands)

1. Read the reference env var (`OP_ANTHROPIC_API_KEY` / `OP_OPENAI_API_KEY`).
2. **If unset** → skip straight to step 4.
3. **If set**, run `op read "$ref"` (the `op://vault/item/field` URI already
   encodes vault/item/field, so no `--account`/`--vault` flags are needed,
   unlike the SixFeetUp example's `op item get`).
   - On success: export the real key var and `exec` the wrapped binary with
     all args forwarded (`exec claude "$@"` / `exec codex "$@"`).
   - On failure (bad reference, not signed in, vault locked, timeout, etc.):
     print the `op` error, then fall through to step 4.
4. **Prompt**: `Continue without an API key? [y/N]` (default **no** on empty
   input).
   - **yes** → `exec` the wrapped binary with all args forwarded, no key
     exported (falls back to the tool's own subscription/login auth).
   - **no** → print a short message and `exit 1`; nothing is launched.

Secrets are never echoed. The only text printed is the `op` error message
(on failure) and the yes/no prompt.

### Where the reference env vars get set

Not part of this change's implementation, but the intended usage: instead of
a project's `.envrc` calling into 1Password eagerly (slow, hangs after idle
periods), it now just does a plain `export OP_ANTHROPIC_API_KEY=op://...`
(or `OP_OPENAI_API_KEY=...`) — instant, no 1Password CLI invocation. The one
actual `op read` call happens only when `cld`/`cdx` is run.

## Testing plan

Manual verification on the Mac after `home-manager switch`:

1. Valid reference set → key resolves silently, `claude`/`codex` launches
   with args forwarded.
2. Reference var unset → prompt appears; confirm both the "y" and "n" paths
   behave as designed.
3. Reference var set to an invalid/unreadable value → `op read` error is
   shown, then the same prompt appears.
4. Confirm `cld` and `cdx` land on `$PATH` after the switch.
