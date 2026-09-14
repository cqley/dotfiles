#!/bin/sh
dir=$(mktemp -d)
git clone https://github.com/cqley/dotfiles "$dir"
doas rm -rf /etc/nixos
doas cp -r "$dir/nixos" /etc/
rm -rf "$dir"
