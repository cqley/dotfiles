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
          ./common.nix
          ./hosts/box
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.cat = {
              imports = [
                ./mngr.nix
                ./hypr.nix
                ./shell.nix
              ];
            };
          }
        ];
      };

      bin = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./common.nix
          ./hosts/bin
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.cat = {
              imports = [
                ./mngr.nix
              ];
            };
          }
        ];
      };
    };
  };
}
