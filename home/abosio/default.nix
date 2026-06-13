
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
    # home-manager 26.05 removed the implicit `Host *` defaults; opt out and
    # declare them explicitly under matchBlocks."*" (values copied verbatim from
    # the old defaults, plus addKeysToAgent which used to be a top-level option).
    enableDefaultConfig = false;
    matchBlocks = {
      "*" = {
        forwardAgent = false;
        addKeysToAgent = "yes";
        compression = false;
        serverAliveInterval = 0;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlMaster = "no";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "no";
      };
      "raspberrypi5 raspberrypi5.local" = {
        forwardAgent = true;
      };
      "git.abosio.com" = {
        port = 2222;
        user = "forgejo";
      };
    };
    extraConfig = ''
      SetEnv TERM=xterm-256color
      IdentityAgent ~/.1password/agent.sock
    '';
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
