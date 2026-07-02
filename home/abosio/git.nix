# abosio's git identity + global ignores.
# Imported by each of abosio's profiles with the appropriate email:
#   - macOS workstation (darwin.nix): work address
#   - NixOS hosts (default.nix):       personal address
# Not used by other users (e.g. jbosio).
{ email }:
{ config, ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user.name = "abosio";
      user.email = email;
      init.defaultBranch = "main";
      pull.rebase = false;
      push.autoSetupRemote = true;
      # Point git at our HM-owned ignore file (not the default git/ignore).
      # See the xdg.configFile note below for why.
      core.excludesFile = "${config.xdg.configHome}/git/ignore-hm";
    };
  };

  # Global gitignore, owned declaratively. Deliberately at git/ignore-hm
  # instead of the default git/ignore: Claude Code writes to ~/.config/git/ignore
  # imperatively, and Home Manager manages files by whole-file symlink and refuses
  # to clobber. The two contending for that single path broke `nixos-rebuild
  # switch`. Splitting them onto separate files lets both coexist permanently.
  xdg.configFile."git/ignore-hm".text = ''
    .envrc
    .aider*
    .vscode
    **/.claude/settings.local.json
  '';
}
