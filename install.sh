#!/bin/sh
dir=$(mktemp -d)
git clone https://github.com/cqley/dotfiles "$dir"
sudo rm -rf /etc/nixos
sudo cp -r "$dir/nixos" /etc/
rm -rf "$dir"
