
{ pkgs, lib, osConfig, ... }:

{
  imports = [
    ../shared/kitty.nix
    ../shared/packages.nix
    ../shared/zsh.nix
  ];

  # Host-specific packages for this user. obs-studio everywhere except norfolk;
  # the commented line shows where a norfolk-only package would go later.
  home.packages =
    lib.optional (osConfig.networking.hostName != "norfolk") pkgs.obs-studio
    # ++ lib.optional (osConfig.networking.hostName == "norfolk") pkgs.pong3d
    ;

  home.username = "abosio";
  home.homeDirectory = "/home/abosio";
  home.stateVersion = "25.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Setup Mozilla
  programs.firefox.enable = true;
  # Keep the legacy profile path (~/.mozilla/firefox); the 26.05 default moved to
  # XDG but home.stateVersion is pinned at 25.05. Setting this explicitly silences
  # the migration warning without moving the existing profile.
  programs.firefox.configPath = ".mozilla/firefox";
  programs.thunderbird = {
    enable = true;
    profiles = {
      default = {
        isDefault = true;
      };
    };
  };

  programs.ssh = {
    enable = true;
    # home-manager 26.05 deprecated `matchBlocks` in favour of `settings` (freeform,
    # OpenSSH directive names) and removed the implicit `Host *` defaults. We opt out
    # of those defaults and declare them explicitly; the module always emits the "*"
    # block last, so per-host overrides keep precedence.
    enableDefaultConfig = false;
    settings = {
      "*" = {
        AddKeysToAgent = "yes";
        Compression = false;
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
        ForwardAgent = false;
        HashKnownHosts = false;
        ServerAliveCountMax = 3;
        ServerAliveInterval = 0;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        SetEnv = { TERM = "xterm-256color"; };
        IdentityAgent = "~/.1password/agent.sock";
      };
      "raspberrypi5 raspberrypi5.local" = {
        ForwardAgent = true;
      };
      "git.abosio.com" = {
        Port = 2222;
        User = "forgejo";
      };
    };
  };


  # Some services
  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 1800;
    enableSshSupport = true;
    pinentry.package = pkgs.pinentry-gnome3;
  };

  dconf.settings = {
    "org/gnome/desktop/input-sources" = {
      xkb-options = ["ctrl:nocaps"];
    };
  };

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

    # Sync
    syncbooks = "rsync -avh --delete  '/home/abosio/Sync/Calibre Library/' /mnt/pi/services/calibre/library/";
  };

}
