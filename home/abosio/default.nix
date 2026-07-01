
{ pkgs, lib, osConfig, ... }:

let
  hostname = osConfig.networking.hostName;
in
{
  imports = [
    ../shared/kitty.nix
    ../shared/packages.nix
    ../shared/vim.nix
    ../shared/zsh.nix
    ./aliases.nix
    (import ./git.nix { email = "bosio76@gmail.com"; })
  ];

  # Host-specific packages for this user: obs-studio everywhere except norfolk;
  # blender only on norfolk.
  home.packages =
    lib.optional (hostname != "norfolk") pkgs.obs-studio
    ++ lib.optional (hostname == "norfolk") pkgs.blender;

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

  # caps -> ctrl, per desktop environment (abosio only; Jayme is unaffected).
  dconf.settings =
    if hostname == "norfolk" then {
      # MATE keyboard xkb options. NOTE: verify the exact key/value on the machine
      # (`dconf watch /` while toggling it in MATE keyboard settings). Fallback if
      # this doesn't take effect: a per-user `setxkbmap -option ctrl:nocaps`
      # autostart entry (still abosio-only, DE-agnostic).
      "org/mate/desktop/peripherals/keyboard/kbd" = {
        options = [ "ctrl\tctrl:nocaps" ];
      };
    } else {
      "org/gnome/desktop/input-sources" = {
        xkb-options = [ "ctrl:nocaps" ];
      };
    };

  # Base aliases come from ./aliases.nix; this is the Linux-only one.
  programs.zsh.shellAliases = {
    syncbooks = "rsync -avh --delete  '/home/abosio/Sync/Calibre Library/' /mnt/pi/services/calibre/library/";
  };

}
