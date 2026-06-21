{ pkgs, pkgs-unstable, lib, ... }:

{
  imports = [
    ../shared/zsh.nix
    ./aliases.nix
    (import ./git.nix { email = "abosio@sixfeetup.com"; })
  ];

  home.username = "abosio";
  home.homeDirectory = "/Users/abosio";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  # direnv (replaces the manual hook/export below; cross-platform HM module).
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
  };

  home.packages = [
    pkgs-unstable.codex
    pkgs-unstable.devenv
    pkgs.bat
    pkgs.openssl
    pkgs.eza
    pkgs.ffmpeg
    pkgs.gh
    pkgs.kubectl
    pkgs.lazygit
    pkgs.mkcert
    pkgs.mpv
    pkgs.nssTools
    pkgs.nodejs
    pkgs.tmux
    pkgs.zoxide
    pkgs.zsh-powerlevel10k
  ];

  home.sessionVariables = {
    XOI_STAGE = "abosio";
    PIP_REQUIRE_VIRTUALENV = "true";
    CPPFLAGS = "-I${pkgs.openssl.dev}/include";
    LDFLAGS = "-L${pkgs.openssl.out}/lib";
    NPM_CONFIG_PREFIX = "$HOME/.npm-global";
  };

  home.sessionPath = [ "$HOME/.npm-global/bin" ];

  # Base aliases (ls/ll/la/grep/cat/cp/mv/rm/history) come from ./aliases.nix.

  programs.zsh.initContent = lib.mkMerge [
  # Content that must appear before p10k instant prompt
  (lib.mkBefore ''
    # Nix daemon — ensure Nix is on PATH early
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
      . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi

    # p10k instant prompt
    if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
      source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
    fi

    # Source p10k theme from Nix store
    source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
    [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
  '')
  (lib.mkAfter ''
    # HOMEBREW
    eval "$(/opt/homebrew/bin/brew shellenv)"

    # PYENV — skip if inside devenv/nix shell
    if [[ -z "$IN_NIX_SHELL" ]]; then
      export PYENV_ROOT="$HOME/.pyenv"
      [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
      eval "$(pyenv init -)"
    fi

    # BREW autocomplete
    if type brew &>/dev/null; then
      FPATH="$(brew --prefix)/share/zsh/site-functions:''${FPATH}"
      autoload -Uz compinit
      compinit
    fi

    # kubectl completion
    source <(kubectl completion zsh)

    # macOS-only aliases
    alias fixaudio="sudo kill \`ps -ax | grep 'coreaudiod' | grep 'sbin' |awk '{print \$1}'\`"
    alias k='kubectl'
    alias ksy='kubectl -n kube-system'
    alias kgp='kubectl get pods'
    alias kgs='kubectl get services'
    alias kcon='kubectl config get-contexts'

    # shrink-video function
    shrink-video() {
      if [[ -z "$1" || -z "$2" ]]; then
        echo "Usage: shrink-video <input_file> <output_file>" >&2
        return 1
      fi
      ffmpeg -i "$1" -vf scale=1270:-2 -crf 30 -preset fast -c:v libx264 "$2"
    }

    # PIPX
    export PATH="$PATH:/Users/abosio/.local/bin"

    # MISE — TODO: remove when xoit project wraps up
    eval "$(~/.local/bin/mise activate zsh)"
  '')
  ];
}
