{
  description = "My NixOS configuration";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
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
  outputs = { self, nixpkgs, home-manager, sops-nix, nixos-secrets }: {
    nixosConfigurations = {
      logan = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.abosio = import ./home.nix;
          }
          sops-nix.nixosModules.sops
        ];
      };
    };
  };
}
