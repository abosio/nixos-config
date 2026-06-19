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

      # Joplin backup aliases (all hosts)
      alias jc="ssh 192.168.50.236 'ls joplin-backups'"
      alias jcplog="ssh 192.168.50.236 'cat services/scripts/joplin-backups.log' | less"
      alias jcp="ssh 192.168.50.236 'ls -lah joplin-backups && ls -lah \"\$(ls -td joplin-backups/*/ | head -1)\" && du -sh \"\$(ls -td joplin-backups/*/ | head -1)\"' && ssh abosio@nostromo.local 'ls -la /volume1/NetBackup/joplin-backups'"
    '';
  };
}
