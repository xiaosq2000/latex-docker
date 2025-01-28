#!/usr/bin/env bash
set -euo pipefail

# Using bridge network mode:
# Extract the display number from DISPLAY (e.g., ":10" from "hostname:10")
# Set the new DISPLAY variable using host.docker.internal
export DISPLAY="host.docker.internal:$(echo $DISPLAY | cut -d: -f2)"

# A workaround for root to use user-level zsh
if [[ ! -f "/bin/zsh" && -f "${XDG_PREFIX_HOME}/bin/zsh" ]]; then
	sudo ln -s "${XDG_PREFIX_HOME}/bin/zsh" /bin/zsh
fi

# SSH
sudo service ssh start

# Git
git config --global user.name "Shuqi XIAO"
git config --global user.email "xiaosq2000@gmail.com"
git lfs install

# The latest version of my dotfiles and submodules.
cd ~
git remote set-url origin "git@github.com:xiaosq2000/dotfiles.git"
git submodule update --init
git pull --recurse-submodules

# Neovim 
nvim --headless "+Lazy! sync" +qa

# Notify me if the container is ready.
if [[ -z "$DBUS_SESSION_BUS_ADDRESS" ]]; then
	if has "notify-send"; then
		notify-send "$(whoami) ready."
	fi
	completed "$(whoami) ready."
fi

exec "$@"
