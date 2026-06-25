#!/bin/sh
dir=$(mktemp -d)
git clone https://github.com/cqley/dotfiles "$dir"
sudo rm -rf /etc/nixos
sudo cp -r "$dir/nixos" /etc/
rm -rf "$dir"

sudo nixos-generate-config
clear
printf "host?\n"
read -r host

sudo mv /etc/nixos/hardware-configuration.nix "/etc/nixos/hosts/$host/"
sudo rm /etc/nixos/configuration.nix
