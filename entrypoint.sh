#!/usr/bin/env bash
set -euo pipefail

# Using bridge network mode:
# Extract just the display number from DISPLAY (e.g., ":10" from "hostname:10")
DISPLAY_NUMBER=$(echo $DISPLAY | cut -d: -f2)
# Set the new DISPLAY variable using host.docker.internal
export DISPLAY=host.docker.internal:$DISPLAY_NUMBER

has() {
	command -v "$1" 1>/dev/null 2>&1
}

if [[ ! -f "/bin/zsh" && -f "${XDG_PREFIX_HOME}/bin/zsh" ]]; then
	sudo ln -s "${XDG_PREFIX_HOME}/bin/zsh" /bin/zsh
fi

if [[ -z "$DBUS_SESSION_BUS_ADDRESS" ]]; then
	if has "notify-send"; then
		notify-send "$(whoami) ready."
	fi
fi

sudo service ssh start

git config --global user.name "Shuqi XIAO"
git config --global user.email "xiaosq2000@gmail.com"
git lfs install

cd ~
git remote set-url origin "git@github.com:xiaosq2000/dotfiles.git"
git submodule update --init
git pull --recurse-submodules

exec "$@"
