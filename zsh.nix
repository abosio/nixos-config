{ config, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    history = {
      size = 1000000;
      path = "${config.xdg.dataHome}/zsh/history";
    };
    sessionVariables = {
      EDITOR = "vim";
      TERMINAL = "kitty";
      BROWSER = "firefox";
    };
    syntaxHighlighting.enable = true;
    shellAliases = {
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

    # Zsh Plugin Manager
    zplug = {
      enable = true;
      plugins = [
        { name = "zsh-users/zsh-autosuggestions"; }
        { name = "zsh-users/zsh-syntax-highlighting"; }
        { name = "zap-zsh/fzf"; }
        { name = "zap-zsh/exa"; }
      ];
    };

    # Extra setup and keybindings
    initContent = ''
      PROMPT_EOL_MARK=\'\'
      eval "$(zoxide init zsh)"

      setopt completeinword NO_flowcontrol NO_listbeep NO_singlelinezle
      autoload -Uz compinit
      compinit

      # keybinds
      bindkey '^ ' autosuggest-accept
      bindkey -v
      bindkey '^R' history-incremental-search-backward
    '';
  };
}