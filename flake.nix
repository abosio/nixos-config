{
  description = "My NixOS configuration";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # TEMPORARY: pinned nixpkgs whose default kernel is 6.18.33, used only for
    # logan's kernel. 6.18.34-6.18.37 regressed amdgpu s2idle resume on the
    # discrete RX 7600M (SMU resume -22 / PCIe AER recovery fail), freezing input
    # for ~30-60s after wake. Drop this input once a fixed 6.18.y lands upstream.
    nixpkgs-kernel.url = "github:NixOS/nixpkgs/b51242d7d43689db2f3be91bd05d5b24fbb469c4";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-secrets = {
      url = "git+ssh://abosio@abosio.com:1022/opt/git/nixos-secrets.git";
      flake = false;
    };
  };
  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, nixpkgs-kernel, home-manager, sops-nix, nixos-secrets }:
  let
    linuxSystem = "x86_64-linux";
    darwinSystem = "aarch64-darwin";

    pkgs-unstable-linux = import nixpkgs-unstable {
      system = linuxSystem;
      config.allowUnfree = true;
    };
    pkgs-unstable-darwin = import nixpkgs-unstable {
      system = darwinSystem;
      config.allowUnfree = true;
    };

    mkHost = { hostname, users }:
      nixpkgs.lib.nixosSystem {
        system = linuxSystem;

        specialArgs = {
          inherit inputs;
        };

        modules = [
          ./hosts/${hostname}
          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              pkgs-unstable = pkgs-unstable-linux;
            };
            home-manager.users = users;
          }
        ];
      };
  in
  {
    nixosConfigurations = {
      logan = mkHost {
        hostname = "logan";
        users = {
          abosio = import ./home/abosio;
        };
      };

      norfolk = mkHost {
        hostname = "norfolk";
        users = {
          abosio = import ./home/abosio;
          jbosio = import ./home/jbosio;
        };
      };
    };

    homeConfigurations."abosio" = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = darwinSystem;
        config.allowUnfree = true;
      };
      extraSpecialArgs = {
        pkgs-unstable = pkgs-unstable-darwin;
      };
      modules = [ ./home/abosio/darwin.nix ];
    };
  };
}
