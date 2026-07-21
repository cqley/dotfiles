{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/86a14b4c-9a4e-4b03-a04e-6d4bfb887d12";
    fsType = "ext4";
    options = [ "noatime" ];
  };

  fileSystems."/mnt/box" = {
    device = "/dev/disk/by-uuid/70da8a3c-5590-4267-8361-1ec111f909da";
    fsType = "ext4";
    options = [ "noatime" ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
