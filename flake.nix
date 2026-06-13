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
    system = "x86_64-linux";
    pkgs-unstable = import nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };

    mkHost = { hostname, users }:
      nixpkgs.lib.nixosSystem {
        inherit system;

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
              inherit pkgs-unstable;
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
  };
}
