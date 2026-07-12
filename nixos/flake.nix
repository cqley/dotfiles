{
  description = "litterbox";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }:
  let
    system = "x86_64-linux";
    pkgs-unstable = import nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    nixosConfigurations = {
      box = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit pkgs-unstable; };
        modules = [
          ./hosts/box/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit pkgs-unstable; };
            home-manager.users.cat = {
              imports = [ ./hosts/box/box.nix ./mdls/hypr.nix ./mdls/qksh.nix ./mdls/btop.nix ./mdls/vi.nix ./mdls/colors.nix ./mdls/obsidian.nix ./mdls/gms/dayz.nix ./mdls/gms/mc.nix ];
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
              imports = [ ./hosts/bin/bin.nix ./mdls/vi.nix ./mdls/btop.nix ];
            };
          }
        ];
      };
    };
  };
}
