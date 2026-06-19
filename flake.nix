{
  description = "My NixOS configuration";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
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
  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, home-manager, sops-nix, nixos-secrets }:
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
      pkgs = nixpkgs.legacyPackages.${darwinSystem};
      extraSpecialArgs = {
        pkgs-unstable = pkgs-unstable-darwin;
      };
      modules = [ ./home/abosio/darwin.nix ];
    };
  };
}
