{ ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user.name = "abosio";
      user.email = "abosio@sixfeetup.com";
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
