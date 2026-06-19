# abosio's git identity + global ignores.
# Imported by each of abosio's profiles with the appropriate email:
#   - macOS workstation (darwin.nix): work address
#   - NixOS hosts (default.nix):       personal address
# Not used by other users (e.g. jbosio).
{ email }:
{
  programs.git = {
    enable = true;
    settings = {
      user.name = "abosio";
      user.email = email;
      init.defaultBranch = "main";
      pull.rebase = false;
      push.autoSetupRemote = true;
    };
    ignores = [
      ".envrc"
      ".aider*"
      ".vscode"
      "**/.claude/settings.local.json"
    ];
  };
}
