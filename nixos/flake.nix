{
  description = "litterbox";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: {
    nixosConfigurations = {
      box = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/box/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.cat = {
              imports = [ ./hosts/box/box.nix ./mdls/hypr.nix ./mdls/qksh.nix ./mdls/vi.nix ./mdls/colors.nix ./mdls/dayz.nix ];
            };
          }
        ];
      };

      bin = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/bin/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.cat = {
              imports = [ ./hosts/bin/bin.nix ./mdls/vi.nix ];
            };
          }
        ];
      };
    };
  };
}
