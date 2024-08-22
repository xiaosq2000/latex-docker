#!/bin/bash

# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Arguments >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
TO_DOWNLOAD=true
TO_EXTRACT=true
TO_BUILD=true
BUILD_WITH_PROXY=false
RUN_WITH_NVIDIA=true
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Arguments <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

# Be safe.
set -euo pipefail

# Logging
INDENT='  '

RESET=$(tput sgr0)
BOLD=$(tput bold)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
PURPLE=$(tput setaf 5)
CYAN=$(tput setaf 6)

error() {
    printf "${RED}${BOLD}ERROR:${RESET} %s\n" "$@" >&2
}
warning() {
    printf "${YELLOW}${BOLD}WARNING:${RESET} %s\n" "$@" >&2
}
info() {
    printf "${GREEN}${BOLD}INFO:${RESET} %s\n" "$@"
}
debug() {
    printf "${BOLD}DEBUG:${RESET} %s\n" "$@"
}

# Check permission. Superuser privilege is used to mount the iso.
if [[ $(id -u) -ne 0 ]]; then
	error "The script needs root privilege to run. Try again with sudo."
	exit 1
fi

# The parent folder of this script.
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# The default path of 'env_file' for Docker Compose
env_file=${script_dir}/.env
# Backup and clear the env_file
if [ -f ${env_file} ]; then
	mv ${env_file} ${env_file}.bak
fi
cat /dev/null >${env_file}

# >>>>>>>>>>>>>>>>>>>>>>>>>> Environment Variables >>>>>>>>>>>>>>>>>>>>>>>>>>>>>
buildtime_env=$(
	cat <<-END

		# >>> as 'service.build.args' in docker-compose.yml >>> 
		DOCKER_BUILDKIT=1
		BASE_IMAGE=ubuntu:22.04
		TEXLIVE_VERSION=2024
		TEXLIVE_SCHEME=full
		GIRARA_VERSION=0.4.4
		ZATHURA_VERSION=0.5.8
		MUPDF_VERSION=1.24.8
		ZATHURA_PDF_MUPDF_VERSION=0.4.4
		NEOVIM_VERSION=0.10.1
		TMUX_GIT_HASH=9ae69c3
		# DOTFILES_GIT_HASH=9233a3e
		SETUP_TIMESTAMP=$(date +%N)
		# <<< as 'service.build.args' in docker-compose.yml <<< 

	END
)

buildtime_proxy_env=$(
	cat <<-END

		BUILDTIME_NETWORK_MODE=host
		# >>> as 'service.build.args' in docker-compose.yml >>> 
		buildtime_http_proxy=http://127.0.0.1:1080
		buildtime_https_proxy=http://127.0.0.1:1080
		BUILDTIME_HTTP_PROXY=http://127.0.0.1:1080
		BUILDTIME_HTTPS_PROXY=http://127.0.0.1:1080
		# <<< as 'service.build.args' in docker-compose.yml <<< 

	END
)

runtime_networking_env=$(
	cat <<-END

		# RUNTIME_NETWORK_MODE=bridge
		# http_proxy=http://host.docker.internal:1080
		# https_proxy=http://host.docker.internal:1080
		# HTTP_PROXY=http://host.docker.internal:1080
		# HTTPS_PROXY=http://host.docker.internal:1080
		RUNTIME_NETWORK_MODE=host
		# http_proxy=http://127.0.0.1:1080
		# https_proxy=http://127.0.0.1:1080
		# HTTP_PROXY=http://127.0.0.1:1080
		# HTTPS_PROXY=http://127.0.0.1:1080

	END
)
user_env=$(
	cat <<-END

		# >>> as 'service.build.args' in docker-compose.yml >>> 
		DOCKER_USER=latex
		DOCKER_HOME=/home/latex
		DOCKER_UID=${SUDO_UID}
		DOCKER_GID=${SUDO_GID}
		# <<< as 'service.build.args' in docker-compose.yml <<< 

	END
)
runtime_env=$(
	cat <<-END

		RUNTIME=runc
		DISPLAY=${DISPLAY}
		SDL_VIDEODRIVER=x11

	END
)
nvidia_runtime_env=$(
	cat <<-END

		RUNTIME=nvidia
		NVIDIA_VISIBLE_DEVICES=all
		NVIDIA_DRIVER_CAPABILITIES=all
		DISPLAY=${DISPLAY}
		SDL_VIDEODRIVER=x11

	END
)
# <<<<<<<<<<<<<<<<<<<<<<<<<< Environment Variables <<<<<<<<<<<<<<<<<<<<<<<<<<<<<

echo "# The file is managed by 'setup.bash'." >> ${env_file}
info "Environment variables are saved to ${env_file}."

# Verify and save the categories of environment variables.
if [[ "${TO_BUILD}" == "true" ]]; then
	echo "${buildtime_env}" >> ${env_file}
else
	warning "TO_BUILD=false"
fi

if [[ "${BUILD_WITH_PROXY}" == "true" ]]; then
	echo "${buildtime_proxy_env}" >> ${env_file}
else
	warning "BUILD_WITH_PROXY=false"
fi

warning "You may check out the runtime networking environment variables."
echo "${runtime_networking_env}" >> ${env_file}
echo "${user_env}" >> ${env_file}
if [ "${RUN_WITH_NVIDIA}" = true ]; then
	echo "${nvidia_runtime_env}" >> ${env_file}
else
	echo "${runtime_env}" >> ${env_file}
fi

info "Environment variables are saved to ${env_file}"
# # Print the env_file to stdout
# cat ${env_file}

# Reference: https://stackoverflow.com/a/30969768
debug "Load varibles from ${env_file} for following usage."
set -o allexport && source ${env_file} && set +o allexport

# >>>>>>>>>>>>>>>>>>>>>>>>>> Environment Variables >>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Downloads <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

downloads_dir="${script_dir}/downloads"
mkdir -p "${downloads_dir}"

# Three helper functions for downloading.
wget_urls=()
wget_paths=()
append_to_list() {
	# $1: flag
	if [ -z "$(eval echo "\$$1")" ]; then
        error "Invalid flag."
		return 0
	fi
	# $2: url
	url="$2"
	# $3: filename
	if [ -z "$3" ]; then
		filename=$(basename "$url")
	else
		filename="$3"
	fi
	if [ ! -f "${downloads_dir}/${filename}" ]; then
		wget_paths+=("${downloads_dir}/${filename}")
		wget_urls+=("$url")
	fi
}
wget_all() {
	for i in "${!wget_urls[@]}"; do
		wget "${wget_urls[i]}" -q --show-progress -O "${wget_paths[i]}"
	done
}
download() {
	# a wrapper of the function "wget_all"
	if [ ${#wget_urls[@]} = 0 ]; then
		info "No download tasks."
	else
		info "${#wget_urls[@]} files to download:"
		(
			IFS=$'\n'
			echo "${wget_urls[*]}"
		)
		wget_all
	fi
}

# Download TexLive (the huge ISO distribution)
# We don't use the helper functions for downloading this one.
if [ ! -f ${downloads_dir}/texlive${TEXLIVE_VERSION}.iso ]; then
	wget https://ctan.mirrors.hoobly.com/systems/texlive/Images/texlive${TEXLIVE_VERSION}.iso -O ${downloads_dir}/texlive${TEXLIVE_VERSION}.iso
	# Check MD5.
	info "Checking the MD5 checksum of texlive${TEXLIVE_VERSION}.iso."
	md5="$(md5sum ${downloads_dir}/texlive${TEXLIVE_VERSION}.iso | awk '{ print $1 }')"
	real_md5="$(wget -qO- https://ctan.math.utah.edu/ctan/tex-archive/systems/texlive/Images/texlive${TEXLIVE_VERSION}.iso.md5 | awk '{ print $1 }')"
	if [ ${md5} != ${real_md5} ]; then
        error "MD5 Unverified. Check your networking status, remove the corrupt file (${downloads_dir}/texlive${TEXLIVE_VERSION}.iso) and execute the script again."
		exit 1
	else
		info "MD5 Verified."
	fi
fi

# Reference: https://unix.stackexchange.com/a/151401
info "Mount the ISO."
mkdir -p ${downloads_dir}/texlive
if ! mountpoint -q -- "${downloads_dir}/texlive"; then
	mount -r ${downloads_dir}/texlive${TEXLIVE_VERSION}.iso ${downloads_dir}/texlive
fi

info "Generate the installation profile of TexLive"
# Reference: https://www.tug.org/texlive/doc/install-tl.html#PROFILES
install_profile=$(
	cat <<-END
		selected_scheme scheme-${TEXLIVE_SCHEME}
		TEXDIR /usr/local/texlive/${TEXLIVE_VERSION}
		TEXMFCONFIG ~/.texlive${TEXLIVE_VERSION}/texmf-config
		TEXMFHOME ~/texmf
		TEXMFLOCAL /usr/local/texlive/texmf-local
		TEXMFSYSCONFIG /usr/local/texlive/${TEXLIVE_VERSION}/texmf-config
		TEXMFSYSVAR /usr/local/texlive/${TEXLIVE_VERSION}/texmf-var
		TEXMFVAR ~/.texlive${TEXLIVE_VERSION}/texmf-var
		binary_x86_64-linux 1
		instopt_adjustpath 0
		instopt_adjustrepo 1
		instopt_letter 0
		instopt_portable 0
		instopt_write18_restricted 1
		tlpdbopt_autobackup 1
		tlpdbopt_backupdir tlpkg/backups
		tlpdbopt_create_formats 1
		tlpdbopt_desktop_integration 1
		tlpdbopt_file_assocs 1
		tlpdbopt_generate_updmap 0
		tlpdbopt_install_docfiles 1
		tlpdbopt_install_srcfiles 1
		tlpdbopt_post_code 1
		tlpdbopt_sys_bin /usr/local/bin
		tlpdbopt_sys_info /usr/local/share/info
		tlpdbopt_sys_man /usr/local/share/man
		tlpdbopt_w32_multi_user 1
	END
)
echo "# The file is managed by 'setup.bash'." > "${downloads_dir}/texlive.profile"
echo "${install_profile}" >> "${downloads_dir}/texlive.profile"
info "TexLive installation profile is generated to ${downloads_dir}/texlive.profile"

# PDF viewer related staff
append_to_list GIRARA_VERSION "https://pwmt.org/projects/girara/download/girara-${GIRARA_VERSION}.tar.xz" ""
append_to_list ZATHURA_VERSION "https://pwmt.org/projects/zathura/download/zathura-${ZATHURA_VERSION}.tar.xz" ""
append_to_list MUPDF_VERSION "https://mupdf.com/downloads/archive/mupdf-${MUPDF_VERSION}-source.tar.gz" ""
append_to_list ZATHURA_PDF_MUPDF_VERSION "https://pwmt.org/projects/zathura-pdf-mupdf/download/zathura-pdf-mupdf-${ZATHURA_PDF_MUPDF_VERSION}.tar.xz" ""

# Typefaces
mkdir -p ${downloads_dir}/typefaces
mkdir -p ${downloads_dir}/typefaces/SourceHanSerifSC
append_to_list 1 "https://github.com/adobe-fonts/source-han-serif/releases/download/2.002R/09_SourceHanSerifSC.zip" "typefaces/SourceHanSerifSC/SourceHanSerifSC.zip"
mkdir -p ${downloads_dir}/typefaces/SourceHanSansSC
append_to_list 1 "https://github.com/adobe-fonts/source-han-sans/releases/download/2.004R/SourceHanSansSC.zip" "typefaces/SourceHanSansSC/SourceHanSansSC.zip"
mkdir -p ${downloads_dir}/typefaces/SourceHanMono
append_to_list 1 "https://github.com/adobe-fonts/source-han-mono/releases/download/1.002/SourceHanMono.ttc" "typefaces/SourceHanMono/SourceHanMono.ttc"
mkdir -p ${downloads_dir}/typefaces/SourceSerif
append_to_list 1 "https://github.com/adobe-fonts/source-serif/releases/download/4.005R/source-serif-4.005_Desktop.zip" "typefaces/SourceSerif/SourceSerif.zip"
mkdir -p ${downloads_dir}/typefaces/SourceSans
append_to_list 1 "https://github.com/adobe-fonts/source-sans/releases/download/3.052R/OTF-source-sans-3.052R.zip" "typefaces/SourceSans/SourceSans.zip"
mkdir -p ${downloads_dir}/typefaces/SourceCodePro
append_to_list 1 "https://github.com/adobe-fonts/source-code-pro/releases/download/2.042R-u%2F1.062R-i%2F1.026R-vf/OTF-source-code-pro-2.042R-u_1.062R-i.zip" "typefaces/SourceCodePro/SourceCodePro.zip"
mkdir -p ${downloads_dir}/typefaces/NerdFontsSourceCodePro
append_to_list 1 "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/SourceCodePro.zip" "typefaces/NerdFontsSourceCodePro/NerdFontsSourceCodePro.zip"
mkdir -p ${downloads_dir}/typefaces/FiraSans
append_to_list 1 "https://github.com/mozilla/Fira/archive/refs/tags/4.106.tar.gz" "typefaces/FiraSans/FiraSans.tar.gz"
mkdir -p ${downloads_dir}/typefaces/FiraCode
append_to_list 1 "https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip" "typefaces/FiraCode/FiraCode.zip"
mkdir -p ${downloads_dir}/typefaces/TexGyreAdventor
append_to_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/adventor/qag2_501otf.zip" "typefaces/TexGyreAdventor/TexGyreAdventor.zip"
mkdir -p ${downloads_dir}/typefaces/TexGyreBonum
append_to_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/bonum/qbk2.004otf.zip" "typefaces/TexGyreBonum/TexGyreBonum.zip"
mkdir -p ${downloads_dir}/typefaces/TexGyreChorus
append_to_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/chorus/qzc2.003otf.zip" "typefaces/TexGyreChorus/TexGyreChorus.zip"
mkdir -p ${downloads_dir}/typefaces/TexGyreCursor
append_to_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/cursor/qcr2.004otf.zip" "typefaces/TexGyreCursor/TexGyreCursor.zip"
mkdir -p ${downloads_dir}/typefaces/TexGyreHero
append_to_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/heros/qhv2.004otf.zip" "typefaces/TexGyreHero/TexGyreHero.zip"
mkdir -p ${downloads_dir}/typefaces/TexGyrePagella
append_to_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/pagella/qpl2_501otf.zip" "typefaces/TexGyrePagella/TexGyrePagella.zip"
mkdir -p ${downloads_dir}/typefaces/TexGyreSchola
append_to_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/schola/qcs2.005otf.zip" "typefaces/TexGyreSchola/TexGyreSchola.zip"
mkdir -p ${downloads_dir}/typefaces/TexGyreTermes
append_to_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/termes/qtm2.004otf.zip" "typefaces/TexGyreTermes/TexGyreTermes.zip"

if [ "${TO_DOWNLOAD}" = true ]; then
	download
else
	warning "TO_DOWNLOAD=false"
fi

# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Downloads >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Extraction <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

extract() {
	info "Extracting all the typefaces."
	# Reference: https://stackoverflow.com/a/2318189
	cd ${downloads_dir}/typefaces/
	find . -name "*.tar.gz" | while read filename; do tar -zxf "$filename" --directory "$(dirname "$filename")" && rm "${filename}"; done
	find . -name "*.zip" | while read filename; do unzip -qq -o -d "$(dirname "$filename")" "$filename" && rm "${filename}"; done
}

if [ "${TO_EXTRACT}" = true ]; then
	extract
else
	warning "TO_EXTRACT=false"
fi

# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Extraction >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

info "Done."
