# abosio's base shell aliases, shared across all of abosio's profiles
# (NixOS hosts + macOS workstation). Host-/OS-specific aliases live in the
# importing profile (e.g. syncbooks on Linux).
{ ... }:
{
  programs.zsh.shellAliases = {
    # Navigation
    ls = "eza";
    ll = "eza -l";
    la = "eza -la";

    # Convenience
    grep = "grep --color=auto";
    cat = "bat -pp"; # A better 'cat'

    # Safety
    cp = "cp -i";
    mv = "mv -i";
    rm = "rm -i";

    # show history from first entry
    history = "history 1";
  };
}
