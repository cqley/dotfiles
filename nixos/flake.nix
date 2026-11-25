{
  description = "litterbox";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helium = {
      url = "github:oxcl/nix-flake-helium-browser";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, helium, ... }:
  let
    system = "x86_64-linux";
    pkgs-unstable = import nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };

    heliumPkg = helium.packages.${system}.helium.overrideAttrs (old: rec {
      version = "0.22.4.1";
      src = nixpkgs.legacyPackages.${system}.fetchurl {
        url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-bin_${version}-1_amd64.deb";
        hash = "sha256-78vTqSQsaXs0t5OWxSKXA407n0L+23kOpLS+n/EbuKk=";
      };
    });
  in {
    nixosConfigurations = {
      box = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit pkgs-unstable; };
        modules = [
          ./hosts/box/configuration.nix
          helium.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            programs.helium = {
              enable = true;
              package = heliumPkg;
            };
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit pkgs-unstable; };
            home-manager.users.cat = {
              imports = [ ./hosts/box/box.nix ];
            };
          }
        ];
      };

      bed = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit pkgs-unstable; };
        modules = [
          ./hosts/bed/configuration.nix
          helium.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            programs.helium = {
              enable = true;
              package = heliumPkg;
            };
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit pkgs-unstable; };
            home-manager.users.cat = {
              imports = [ ./hosts/bed/bed.nix ];
            };
          }
        ];
      };

      bin = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit pkgs-unstable; };
        modules = [
          ./hosts/bin/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit pkgs-unstable; };
            home-manager.users.cat = {
              imports = [ ./hosts/bin/bin.nix ];
            };
          }
        ];
      };
    };
  };
}
