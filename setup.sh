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
	printf '%s\n' "${BOLD}${GREY}DEBUG:${RESET} $*"
}

# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Boilerplate <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Arguments >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

build="false"
build_with_proxy="false"
run_with_proxy="false"
run_with_nvidia="false"
download_texlive="false"
download_zathura_src="false"
download_typefaces="false"
extract_typefaces="false"

usage() {
	printf "%s\n" \
		"Usage: " \
		"${INDENT}$0 [option]" \
		"" \
		"${INDENT}Download a lot of stuff and generate environment variables to '.env' for both build-time and run-time Docker usage." \
		"${INDENT}${RED}Before running, You are suggested checking out the environment variables written in $0.${RESET}" \
		""

	printf "%s\n" \
		"Options: " \
		"${INDENT}-h, --help                       " \
		"${INDENT}-b, --build                      " \
		"${INDENT}-bp, --build_with_proxy          " \
		"${INDENT}-rp, --run_with_proxy            " \
		"${INDENT}-rn, --run_with_nvidia           " \
		"${INDENT}-dt, --download_texlive          " \
		"${INDENT}-dz, --download_zathura_src      " \
		"${INDENT}-dtf, --download_typefaces       " \
		"${INDENT}-et, --extract_typefaces         " \
		""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
	case "$1" in
	-h | --help)
		usage
		exit 0
		;;
	-b | --build)
		build=true
		shift
		;;
	-bp | --build_with_proxy)
		build_with_proxy=true
		shift
		;;
	-rp | --run_with_proxy)
		run_with_proxy=true
		shift
		;;
	-rn | --run_with_nvidia)
		run_with_nvidia=true
		shift
		;;
	-dt | --download_texlive)
		download_texlive=true
		shift
		;;
	-dz | --download_zathura_src)
		download_zathura_src=true
		shift
		;;
	-dtf | --download_typefaces)
		download_typefaces=true
		shift
		;;
	-et | --extract_typefaces)
		extract_typefaces=true
		shift
		;;
	*)
		error "Unknown argument: $1"
		usage
		;;
	esac
done

if [[ $# == 0 ]]; then
	usage
fi

printf "%s\n" "${GREEN}Given Arguments${RESET}:" \
	"${INDENT}build=${BOLD}$build${RESET}" \
	"${INDENT}build_with_proxy=${BOLD}$build_with_proxy${RESET}" \
	"${INDENT}run_with_proxy=${BOLD}$run_with_proxy${RESET}" \
	"${INDENT}download_texlive=${BOLD}$download_texlive${RESET}" \
	"${INDENT}download_zathura_src=${BOLD}$download_zathura_src${RESET}" \
	"${INDENT}download_typefaces=${BOLD}$download_typefaces${RESET}" \
	"${INDENT}extract_typefaces=${BOLD}$extract_typefaces${RESET}" \
	"${INDENT}run_with_nvidia=${BOLD}$run_with_nvidia${RESET}" \
	""

# TODO: autocompletion of arguments

# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Arguments <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

# Check permission. Superuser privilege is used to mount the iso.
if [[ $(id -u) -ne 0 ]]; then
	error "The script needs root privilege to run. Try again with sudo."
	exit 1
fi

# The parent folder of this script.
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# The default path of 'env_file' for Docker Compose
env_file=${script_dir}/.env

# Clear the file
cat /dev/null >${env_file}

# >>>>>>>>>>>>>>>>>>>>>>>>>> Environment Variables >>>>>>>>>>>>>>>>>>>>>>>>>>>>>
buildtime_env=$(
	cat <<-END

		# >>> as services.latex.build.args
		DOCKER_BUILDKIT=1
		BASE_IMAGE=ubuntu:22.04
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
		# <<< as services.latex.build.args

	END
)
if [[ "$build_with_proxy" == "true" ]]; then
	warning "Make sure you have configured the 'buildtime_networking_env' in setup.bash."
	buildtime_networking_env=$(
		cat <<-END

			# >>> as services.latex.build.args
			BUILDTIME_NETWORK_MODE=host
			buildtime_http_proxy=http://127.0.0.1:1080
			buildtime_https_proxy=http://127.0.0.1:1080
			BUILDTIME_HTTP_PROXY=http://127.0.0.1:1080
			BUILDTIME_HTTPS_PROXY=http://127.0.0.1:1080
			# <<< as services.latex.build.args

		END
	)
else
	buildtime_networking_env=$(
		cat <<-END

			# >>> as services.latex.build.args
			BUILDTIME_NETWORK_MODE=host
			# <<< as services.latex.build.args

		END
	)
fi
if [[ "$run_with_proxy" == "true" ]]; then
	warning "Make sure you have configured the 'runtime_networking_env' in setup.bash."
	runtime_networking_env=$(
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
	runtime_networking_env=$(
		cat <<-END

			RUNTIME_NETWORK_MODE=bridge

		END
	)
fi
user_env=$(
	cat <<-END

		# >>> as services.latex.build.args
		DOCKER_USER=latex
		DOCKER_HOME=/home/latex
		DOCKER_UID=${SUDO_UID}
		DOCKER_GID=${SUDO_GID}
		# <<< as services.latex.build.args

	END
)
if [[ "$run_with_nvidia" == "true" ]]; then
	runtime_env=$(
		cat <<-END

			RUNTIME=nvidia
			NVIDIA_VISIBLE_DEVICES=all
			NVIDIA_DRIVER_CAPABILITIES=all
			DISPLAY=${DISPLAY}
			SDL_VIDEODRIVER=x11

		END
	)
else
	runtime_env=$(
		cat <<-END

			RUNTIME=runc
			DISPLAY=${DISPLAY}
			SDL_VIDEODRIVER=x11

		END
	)
fi

info "Environment variables will be saved to ${BOLD}${env_file}${RESET}."
echo "# ! The file is managed by 'setup.bash'." >>${env_file}
echo "# ! Don't modify it manually. Change 'setup.bash' instead." >>${env_file}
# Verify and save the categories of environment variables.
if [[ "$build" == "true" ]]; then
	echo "${buildtime_env}" >>${env_file}
	echo "${buildtime_networking_env}" >>${env_file}
	debug "Replace 'services.latex.build.args' in ${BOLD}docker-compose.yml${RESET}."
	python3 "$script_dir/setup.d/build_args.py" "latex"
fi
echo "${runtime_networking_env}" >>${env_file}
echo "${user_env}" >>${env_file}
echo "${runtime_env}" >>${env_file}
python3 "$script_dir/setup.d/nvidia.py" "latex"
# Reference: https://stackoverflow.com/a/30969768
debug "Load varibles from ${env_file} for following usage in this script."
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
	echo "# ! The file is managed by 'setup.bash'." >"${downloads_dir}/texlive.profile"
	echo "# ! Don't modify it manually. Change 'setup.bash' instead." >>"${downloads_dir}/texlive.profile"
	echo "${install_profile}" >>"${downloads_dir}/texlive.profile"
	info "TeXLive installation profile is generated to ${BOLD}${downloads_dir}/texlive.profile${RESET}."
}
if [[ "$download_texlive" == "true" ]]; then
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
		info "No download tasks."
	else
		info "${#wget_urls[@]} files to download:"
		(
			IFS=$'\n'
			echo "${wget_urls[*]}"
		)
		_wget_all
	fi
}

if [[ "$download_zathura_src" == "true" ]]; then
	# PDF viewer related staff
	warning "Make sure you have set the environment variables related to zathura versions."
	_append_to_list GIRARA_VERSION "https://pwmt.org/projects/girara/download/girara-${GIRARA_VERSION}.tar.xz" ""
	_append_to_list ZATHURA_VERSION "https://pwmt.org/projects/zathura/download/zathura-${ZATHURA_VERSION}.tar.xz" ""
	_append_to_list MUPDF_VERSION "https://mupdf.com/downloads/archive/mupdf-${MUPDF_VERSION}-source.tar.gz" ""
	_append_to_list ZATHURA_PDF_MUPDF_VERSION "https://pwmt.org/projects/zathura-pdf-mupdf/download/zathura-pdf-mupdf-${ZATHURA_PDF_MUPDF_VERSION}.tar.xz" ""
fi

if [[ "$download_typefaces" == "true" ]]; then
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

if [ "$extract_typefaces" = "true" ]; then
	info "Extracting all the typefaces."
	# Reference: https://stackoverflow.com/a/2318189
	cd ${downloads_dir}/typefaces/
	find . -name "*.tar.gz" | while read filename; do tar -zxf "$filename" --directory "$(dirname "$filename")" && rm "${filename}"; done
	find . -name "*.zip" | while read filename; do unzip -qq -o -d "$(dirname "$filename")" "$filename" && rm "${filename}"; done
fi
# <<<<<<<<<<<<<<<<<<<<<<<<< Download and Extraction <<<<<<<<<<<<<<<<<<<<<<<<<<<<

info "Done!"