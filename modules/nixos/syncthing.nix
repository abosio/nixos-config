# modules/nixos/syncthing.nix
# Host-aware: each host syncs with every *other* device, never itself.
# Today the secrets file holds only gotham + MBP, so filtering out "logan"
# is a no-op and Logan's device set is unchanged.
{ config, inputs, lib, ... }:

let
  allDevices = import "${inputs.nixos-secrets}/syncthing-devices.nix";
  devices = lib.filterAttrs (name: _: name != config.networking.hostName) allDevices;
in
{
  services.syncthing = {
    enable = true;
    user = "abosio";
    openDefaultPorts = true; # Open ports in the firewall for Syncthing
    dataDir = "/home/abosio/.local/share/syncthing";
    configDir = "/home/abosio/.config/syncthing";
    settings = {
      devices = devices;
      folders."default" = {
        label = "Default Folder";
        path = "/home/abosio/Sync";
        devices = builtins.attrNames devices;
      };
    };
  };
}
