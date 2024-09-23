#!/bin/bash

# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Boilerplate >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

set -euo pipefail
INDENT='    '
BOLD="$(tput bold 2>/dev/null || printf '')"
GREY="$(tput setaf 0 2>/dev/null || printf '')"
UNDERLINE="$(tput smul 2>/dev/null || printf '')"
RED="$(tput setaf 1 2>/dev/null || printf '')"
GREEN="$(tput setaf 2 2>/dev/null || printf '')"
YELLOW="$(tput setaf 3 2>/dev/null || printf '')"
BLUE="$(tput setaf 4 2>/dev/null || printf '')"
MAGENTA="$(tput setaf 5 2>/dev/null || printf '')"
RESET="$(tput sgr0 2>/dev/null || printf '')"
error() {
	printf '%s\n' "${BOLD}${RED}ERROR:${RESET} $*" >&2
}
warning() {
	printf '%s\n' "${BOLD}${YELLOW}WARNING:${RESET} $*"
}
info() {
	printf '%s\n' "${BOLD}${GREEN}INFO:${RESET} $*"
}
debug() {
	set +u
	if [[ "$DEBUG" == "true" ]]; then
		set -u
		printf '%s\n' "${BOLD}${GREY}DEBUG:${RESET} $*"
	fi
}
completed() {
	printf '%s\n' "${BOLD}${GREEN}✓${RESET} $*"
}
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Boilerplate <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Arguments >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

BUILD="false"
BUILD_PROXY="false"
RUN_PROXY="false"
NVIDIA="false"
WAYLAND="false"
DOWNLOAD_TEXLIVE="false"
DOWNLOAD_ZATHURA_SRC="false"
DOWNLOAD_TYPEFACES="false"
EXTRACT_TYPEFACES="false"

usage() {
	printf "%s\n" \
		"Usage: " \
		"${INDENT}$0 [option]" \
		"" \
		"${INDENT}Download specified build-time dependencies." \
		"${INDENT}Generate 'docker-compose.yml' and '.env' for Docker build-time and run-time usage." \
		"" \
		"${INDENT}${BOLD}Before running, You could check out the environment variables written in $0.${RESET}" \
		"" \
		"${INDENT}Recommended command for the first time," \
		"" \
		"${INDENT}${INDENT}\$ sudo $0 -b -dt -dtf -et" \
		""

	printf "%s\n" \
		"Options: " \
		"${INDENT}-b, --build                    Generate build-time environment variables for 'docker-compose.yml'." \
		"${INDENT}                               If not given, only run-time environment variables will be generated." \
		"" \
		"${INDENT}-bp, --build-proxy             Use networking proxy for docker image build-time." \
		"${INDENT}-rp, --run-proxy               Use networking proxy for docker container run-time." \
		"" \
		"${INDENT}-n, --nvidia                   Configure NVIDIA container runtime. Make sure the nvidia container toolkit is installed and configured." \
		"${INDENT}                               Reference: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html" \
		"" \
		"${INDENT}-w, --wayland                  Configure (X)WAYLAND run-time environment variables." \
		"${INDENT}                               If not given, X11 run-time environment variables will be configured." \
		"" \
		"${INDENT}-dt, --download-texlive        " \
		"${INDENT}-dz, --download-zathura-src    " \
		"${INDENT}-dtf, --download-typefaces     " \
		"${INDENT}-et, --extract-typefaces       " \
		"" \
		"${INDENT}-h, --help                     Display help messages." \
		"${INDENT}--debug                        Display verbose logging for debugging." \
		""
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	-h | --help)
		usage
		exit 0
		;;
	--debug)
		DEBUG=true
        shift
		;;
	-b | --build)
		BUILD=true
		shift
		;;
	-bp | --build-proxy)
		BUILD_PROXY=true
		shift
		;;
	-rp | --run-proxy)
		RUN_PROXY=true
		shift
		;;
	-n | --nvidia)
		NVIDIA=true
		shift
		;;
	-w | --wayland)
		WAYLAND=true
		shift
		;;
	-dt | --download-texlive)
		DOWNLOAD_TEXLIVE=true
		shift
		;;
	-dz | --download-zathura-src)
		DOWNLOAD_ZATHURA_SRC=true
		shift
		;;
	-dtf | --download-typefaces)
		DOWNLOAD_TYPEFACES=true
		shift
		;;
	-et | --extract-typefaces)
		EXTRACT_TYPEFACES=true
		shift
		;;
	*)
		error "Unknown argument: $1"
		usage
		;;
	esac
done

# TODO: autocompletion of arguments

# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Arguments <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

# The parent folder of this script.
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# The default path of 'env_file' for Docker Compose
env_file="${script_dir}/.env"

if [[ -f "$env_file" ]]; then
    rm $env_file
fi
touch $env_file
if [[ $(id -u) -eq 0 ]]; then
    chown ${SUDO_USER}:${SUDO_USER} $env_file
fi


# >>>>>>>>>>>>>>>>>>>>>>>>>> Environment Variables >>>>>>>>>>>>>>>>>>>>>>>>>>>>>
 
SERVICE_NAME="latex"
python3 "$script_dir/setup.d/deploy.py" --service-name "${SERVICE_NAME}" --clear

compose_env=$(
	cat <<-END

		IMAGE_NAME=latex
		IMAGE_TAG=latest
		CONTAINER_NAME=latex

	END
)
build_env=$(
	cat <<-END

		# >>> as services.${SERVICE_NAME}.build.args
		DOCKER_BUILDKIT=1
		BASE_IMAGE=ubuntu:24.04
		XDG_PREFIX_DIR=/usr/local
		TEXLIVE_VERSION=2024
		TEXLIVE_SCHEME=full
		TO_BUILD_ZATHURA=false
		# GIRARA_VERSION=0.4.4
		# ZATHURA_VERSION=0.5.8
		# MUPDF_VERSION=1.24.8
		# ZATHURA_PDF_MUPDF_VERSION=0.4.4
		NEOVIM_VERSION=0.10.1
		TMUX_GIT_HASH=9ae69c3
		SETUP_TIMESTAMP=$(date +%N)
		# <<< as services.${SERVICE_NAME}.build.args

	END
)
if [[ "$BUILD_PROXY" == "true" ]]; then
	warning "Make sure you have configured the 'buildtime_networking_env' in setup.sh."
	build_networking_env=$(
		cat <<-END

			# >>> as services.${SERVICE_NAME}.build.args
			BUILDTIME_NETWORK_MODE=host
			buildtime_http_proxy=http://127.0.0.1:1080
			buildtime_https_proxy=http://127.0.0.1:1080
			BUILDTIME_HTTP_PROXY=http://127.0.0.1:1080
			BUILDTIME_HTTPS_PROXY=http://127.0.0.1:1080
			# <<< as services.${SERVICE_NAME}.build.args

		END
	)
else
	build_networking_env=$(
		cat <<-END

			# >>> as services.${SERVICE_NAME}.build.args
			BUILDTIME_NETWORK_MODE=host
			# <<< as services.${SERVICE_NAME}.build.args

		END
	)
fi
if [[ "$RUN_PROXY" == "true" ]]; then
	warning "Make sure you have configured the 'runtime_networking_env' in setup.sh."
	run_networking_env=$(
		cat <<-END

			RUNTIME_NETWORK_MODE=bridge
			http_proxy=http://host.docker.internal:1080
			https_proxy=http://host.docker.internal:1080
			HTTP_PROXY=http://host.docker.internal:1080
			HTTPS_PROXY=http://host.docker.internal:1080
			# RUNTIME_NETWORK_MODE=host
			# http_proxy=http://127.0.0.1:1080
			# https_proxy=http://127.0.0.1:1080
			# HTTP_PROXY=http://127.0.0.1:1080
			# HTTPS_PROXY=http://127.0.0.1:1080

		END
	)
else
	run_networking_env=$(
		cat <<-END

			RUNTIME_NETWORK_MODE=bridge

		END
	)
fi
if [[ $(id -u) -ne 0 ]]; then
    run_and_build_user_env=$(
        cat <<-END

			# >>> as services.${SERVICE_NAME}.build.args
			DOCKER_USER=latex
			DOCKER_HOME=/home/latex
			DOCKER_UID=$(id -u)
			DOCKER_GID=$(id -g)
			# <<< as services.${SERVICE_NAME}.build.args

		END
    )
else
    run_and_build_user_env=$(
        cat <<-END

			# >>> as services.${SERVICE_NAME}.build.args
			DOCKER_USER=latex
			DOCKER_HOME=/home/latex
			DOCKER_UID=${SUDO_UID}
			DOCKER_GID=${SUDO_GID}
			# <<< as services.${SERVICE_NAME}.build.args

		END
    )
fi
if [[ "$NVIDIA" == "true" ]]; then
	container_runtime_env=$(
		cat <<-END

			RUNTIME=nvidia
			NVIDIA_VISIBLE_DEVICES=all
			NVIDIA_DRIVER_CAPABILITIES=all

		END
	)
	python3 "$script_dir/setup.d/deploy.py" --service-name "${SERVICE_NAME}" --nvidia
else
	container_runtime_env=$(
		cat <<-END

			RUNTIME=runc

		END
	)
fi
if [[ "${WAYLAND}" == true ]]; then
	display_runtime_env=$(
		cat <<-END

			DISPLAY=${DISPLAY}
			WAYLAND_DISPLAY=${WAYLAND_DISPLAY}
			SDL_VIDEODRIVER=wayland
			QT_QPA_PLATFORM=wayland

		END
	)
else
	display_runtime_env=$(
		cat <<-END

			DISPLAY=${DISPLAY}
			SDL_VIDEODRIVER=x11

		END
	)
fi

echo "# ! The file is managed by '$(basename "$0")'." >>${env_file}
echo "# ! Don't edit '${env_file}' manually. Change '$(basename "$0")' instead." >>${env_file}
echo "${compose_env}" >>${env_file}
echo "${run_and_build_user_env}" >>${env_file}
if [[ "${BUILD}" = true ]]; then
    # Check permission. Superuser privilege is used to mount the iso.
    if [[ $(id -u) -ne 0 ]]; then
        error "The script needs root privilege to run. Try again with sudo."
        exit 1
    fi
	echo "${build_env}" >>${env_file}
	echo "${build_networking_env}" >>${env_file}
	python3 "$script_dir/setup.d/build_args.py" "${SERVICE_NAME}"
fi
echo "${run_networking_env}" >>${env_file}
echo "${container_runtime_env}" >>${env_file}
echo "${display_runtime_env}" >>${env_file}
debug "Environment variables are saved to ${env_file}"

# Load varibles from a file
# Reference: https://stackoverflow.com/a/30969768
set -o allexport && source ${env_file} && set +o allexport

# >>>>>>>>>>>>>>>>>>>>>>>>>> Environment Variables >>>>>>>>>>>>>>>>>>>>>>>>>>>>>

downloads_dir="${script_dir}/downloads"
mkdir -p "${downloads_dir}"

# >>>>>>>>>>>>>>>>>>>>>>>>>>>>> Download TexLive  >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_download_texlive() {
	# We use the huge ISO distribution.
	if [[ ! -f ${downloads_dir}/texlive${TEXLIVE_VERSION}.iso ]]; then
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
	# Reference: https://www.tug.org/texlive/doc/install-tl.html#PROFILES
	install_profile=$(
		cat <<-END
			selected_scheme scheme-${TEXLIVE_SCHEME}
			TEXDIR ${XDG_PREFIX_DIR}/texlive/${TEXLIVE_VERSION}
			TEXMFCONFIG ~/.texlive${TEXLIVE_VERSION}/texmf-config
			TEXMFHOME ~/texmf
			TEXMFLOCAL ${XDG_PREFIX_DIR}/texlive/texmf-local
			TEXMFSYSCONFIG ${XDG_PREFIX_DIR}/texlive/${TEXLIVE_VERSION}/texmf-config
			TEXMFSYSVAR ${XDG_PREFIX_DIR}/texlive/${TEXLIVE_VERSION}/texmf-var
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
			tlpdbopt_sys_bin ${XDG_PREFIX_DIR}/bin
			tlpdbopt_sys_info ${XDG_PREFIX_DIR}/share/info
			tlpdbopt_sys_man ${XDG_PREFIX_DIR}/share/man
			tlpdbopt_w32_multi_user 1
		END
	)
	echo "# ! The file is managed by 'setup.sh'." >"${downloads_dir}/texlive.profile"
	echo "# ! Don't modify it manually. Change 'setup.sh' instead." >>"${downloads_dir}/texlive.profile"
	echo "${install_profile}" >>"${downloads_dir}/texlive.profile"
	info "TeXLive installation profile is generated to ${BOLD}${downloads_dir}/texlive.profile${RESET}."
}
if [[ "$DOWNLOAD_TEXLIVE" == "true" ]]; then
	_download_texlive
fi
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<< Download TeXLive <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

# >>>>>>>>>>>>>>>>>>>>>>>>> Download and Extraction >>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Three helper functions for downloading.
wget_urls=()
wget_paths=()
_append_to_list() {
	# $1: flag
	if [ -z "$(eval echo "\$$1")" ]; then
		warning "$1 is unset. Failed to append to the downloading list."
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
_wget_all() {
	for i in "${!wget_urls[@]}"; do
		wget "${wget_urls[i]}" -q --show-progress -O "${wget_paths[i]}"
	done
}
_download_everything() {
	# a wrapper of the function "wget_all"
	if [ ${#wget_urls[@]} = 0 ]; then
		debug "No download tasks."
	else
		info "${#wget_urls[@]} files to download:"
		(
			IFS=$'\n'
			echo "${wget_urls[*]}"
		)
		_wget_all
	fi
}

if [[ "$DOWNLOAD_ZATHURA_SRC" == "true" ]]; then
	warning "Make sure:
    1. 'setup.sh': set the environment variables related to zathura versions.
    2. 'Dockerfile': uncomment the related lines.
    "
	_append_to_list GIRARA_VERSION "https://pwmt.org/projects/girara/download/girara-${GIRARA_VERSION}.tar.xz" ""
	_append_to_list ZATHURA_VERSION "https://pwmt.org/projects/zathura/download/zathura-${ZATHURA_VERSION}.tar.xz" ""
	_append_to_list MUPDF_VERSION "https://mupdf.com/downloads/archive/mupdf-${MUPDF_VERSION}-source.tar.gz" ""
	_append_to_list ZATHURA_PDF_MUPDF_VERSION "https://pwmt.org/projects/zathura-pdf-mupdf/download/zathura-pdf-mupdf-${ZATHURA_PDF_MUPDF_VERSION}.tar.xz" ""
fi

if [[ "$DOWNLOAD_TYPEFACES" == "true" ]]; then
	mkdir -p ${downloads_dir}/typefaces
	mkdir -p ${downloads_dir}/typefaces/SourceHanSerifSC
	_append_to_list 1 "https://github.com/adobe-fonts/source-han-serif/releases/download/2.002R/09_SourceHanSerifSC.zip" "typefaces/SourceHanSerifSC/SourceHanSerifSC.zip"
	mkdir -p ${downloads_dir}/typefaces/SourceHanSansSC
	_append_to_list 1 "https://github.com/adobe-fonts/source-han-sans/releases/download/2.004R/SourceHanSansSC.zip" "typefaces/SourceHanSansSC/SourceHanSansSC.zip"
	mkdir -p ${downloads_dir}/typefaces/SourceHanMono
	_append_to_list 1 "https://github.com/adobe-fonts/source-han-mono/releases/download/1.002/SourceHanMono.ttc" "typefaces/SourceHanMono/SourceHanMono.ttc"
	mkdir -p ${downloads_dir}/typefaces/SourceSerif
	_append_to_list 1 "https://github.com/adobe-fonts/source-serif/releases/download/4.005R/source-serif-4.005_Desktop.zip" "typefaces/SourceSerif/SourceSerif.zip"
	mkdir -p ${downloads_dir}/typefaces/SourceSans
	_append_to_list 1 "https://github.com/adobe-fonts/source-sans/releases/download/3.052R/OTF-source-sans-3.052R.zip" "typefaces/SourceSans/SourceSans.zip"
	mkdir -p ${downloads_dir}/typefaces/SourceCodePro
	_append_to_list 1 "https://github.com/adobe-fonts/source-code-pro/releases/download/2.042R-u%2F1.062R-i%2F1.026R-vf/OTF-source-code-pro-2.042R-u_1.062R-i.zip" "typefaces/SourceCodePro/SourceCodePro.zip"
	mkdir -p ${downloads_dir}/typefaces/NerdFontsSourceCodePro
	_append_to_list 1 "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/SourceCodePro.zip" "typefaces/NerdFontsSourceCodePro/NerdFontsSourceCodePro.zip"
	mkdir -p ${downloads_dir}/typefaces/FiraSans
	_append_to_list 1 "https://github.com/mozilla/Fira/archive/refs/tags/4.106.tar.gz" "typefaces/FiraSans/FiraSans.tar.gz"
	mkdir -p ${downloads_dir}/typefaces/FiraCode
	_append_to_list 1 "https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip" "typefaces/FiraCode/FiraCode.zip"
	mkdir -p ${downloads_dir}/typefaces/TexGyreAdventor
	_append_to_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/adventor/qag2_501otf.zip" "typefaces/TexGyreAdventor/TexGyreAdventor.zip"
	mkdir -p ${downloads_dir}/typefaces/TexGyreBonum
	_append_to_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/bonum/qbk2.004otf.zip" "typefaces/TexGyreBonum/TexGyreBonum.zip"
	mkdir -p ${downloads_dir}/typefaces/TexGyreChorus
	_append_to_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/chorus/qzc2.003otf.zip" "typefaces/TexGyreChorus/TexGyreChorus.zip"
	mkdir -p ${downloads_dir}/typefaces/TexGyreCursor
	_append_to_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/cursor/qcr2.004otf.zip" "typefaces/TexGyreCursor/TexGyreCursor.zip"
	mkdir -p ${downloads_dir}/typefaces/TexGyreHero
	_append_to_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/heros/qhv2.004otf.zip" "typefaces/TexGyreHero/TexGyreHero.zip"
	mkdir -p ${downloads_dir}/typefaces/TexGyrePagella
	_append_to_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/pagella/qpl2_501otf.zip" "typefaces/TexGyrePagella/TexGyrePagella.zip"
	mkdir -p ${downloads_dir}/typefaces/TexGyreSchola
	_append_to_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/schola/qcs2.005otf.zip" "typefaces/TexGyreSchola/TexGyreSchola.zip"
	mkdir -p ${downloads_dir}/typefaces/TexGyreTermes
	_append_to_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/termes/qtm2.004otf.zip" "typefaces/TexGyreTermes/TexGyreTermes.zip"
fi

_download_everything

if [ "$EXTRACT_TYPEFACES" = "true" ]; then
	info "Extracting all the typefaces."
	# Reference: https://stackoverflow.com/a/2318189
	cd ${downloads_dir}/typefaces/
	find . -name "*.tar.gz" | while read filename; do tar -zxf "$filename" --directory "$(dirname "$filename")" && rm "${filename}"; done
	find . -name "*.zip" | while read filename; do unzip -qq -o -d "$(dirname "$filename")" "$filename" && rm "${filename}"; done
fi
# <<<<<<<<<<<<<<<<<<<<<<<<< Download and Extraction <<<<<<<<<<<<<<<<<<<<<<<<<<<<

completed "Done!"
