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
      TERM = "xterm-256color";
    };
    syntaxHighlighting.enable = true;

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
      # vi keymap leaves ^A/^E as self-insert; restore emacs-style line navigation
      bindkey '^A' beginning-of-line
      bindkey '^E' end-of-line
    '';
  };
}
