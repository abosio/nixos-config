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

      if key="$(op read "$ref")" && [[ -n "$key" ]]; then
        export ${exportVar}="$key"
        exec ${binary} "$@"
      else
        resolve_failed "op read failed (see error above, if any)." "$@"
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
