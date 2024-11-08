#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
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
completed() {
	printf '%s\n' "${BOLD}${GREEN}✓${RESET} $*"
}

usage() {
	printf "%s\n" \
		"Usage: " \
		"${INDENT}$0 [option]" \
		"" \
		"Some descriptions." \
		""
	printf "%s\n" \
		"Options: " \
		"${INDENT}-h, --help                            Display help messages" \
		"${INDENT}--env-file                            " \
		"${INDENT}--downloads-dir DOWNLOADS_DIR         Path to the directory containing things to download" \
		"${INDENT}--download-texlive                                                                       " \
		"${INDENT}--generate-texlive-install-profile                                                       " \
		"${INDENT}--mount                               Mount TexLive ISO (superuser privilege required)   " \
		"${INDENT}--download-typefaces                                                                     " \
		"${INDENT}--extract-typefaces                                                                      " \
		"${INDENT}--remove-typefaces-zipfiles                                                              " \
		""
}

MOUNT=false
ENV_FILE="${SCRIPT_DIR}/.env"
DOWNLOADS_DIR="${SCRIPT_DIR}/downloads"
DOWNLOAD_TEXLIVE=false
GENERATE_TEXLIVE_INSTALL_PROFILE=false
DOWNLOAD_TYPEFACES=false
EXTRACT_TYPEFACES=false
REMOVE_TYPEFACES_ZIPFILES=false
while [[ $# -gt 0 ]]; do
	case "$1" in
	-h | --help)
		usage
		exit 0
		;;
	--env-file)
		ENV_FILE="${2}"
		shift 2
		;;
	--mount)
		MOUNT="true"
		shift 1
		;;
	--downloads-dir)
		DOWNLOADS_DIR="${2%/}"
		shift 2
		;;
	--download-texlive)
		DOWNLOAD_TEXLIVE="true"
		shift 1
		;;
	--download-typefaces)
		DOWNLOAD_TYPEFACES="true"
		shift 1
		;;
	--generate-texlive-install-profile)
		GENERATE_TEXLIVE_INSTALL_PROFILE="true"
		shift 1
		;;
	--extract-typefaces)
		EXTRACT_TYPEFACES="true"
		shift 1
		;;
	--remove-typefaces-zipfiles)
		REMOVE_TYPEFACES_ZIPFILES="true"
		shift 1
		;;
	*)
		error "Unknown argument: $1"
		usage
		exit 1
		;;
	esac
done

set -o allexport && source ${ENV_FILE} && set +o allexport

if [[ "$DOWNLOAD_TEXLIVE" == "true" ]]; then
	# We use the huge ISO distribution.
	if [[ ! -f ${DOWNLOADS_DIR}/texlive${TEXLIVE_VERSION}.iso ]]; then
		wget https://ctan.mirrors.hoobly.com/systems/texlive/Images/texlive${TEXLIVE_VERSION}.iso -O ${DOWNLOADS_DIR}/texlive${TEXLIVE_VERSION}.iso
	fi
	# Check MD5.
	info "Checking the MD5 checksum of texlive${TEXLIVE_VERSION}.iso."
	md5="$(md5sum ${DOWNLOADS_DIR}/texlive${TEXLIVE_VERSION}.iso | awk '{ print $1 }')"
	real_md5="$(wget -qO- https://ctan.math.utah.edu/ctan/tex-archive/systems/texlive/Images/texlive${TEXLIVE_VERSION}.iso.md5 | awk '{ print $1 }')"
	if [ ${md5} != ${real_md5} ]; then
		error "MD5 Unverified. Check your networking status, remove the corrupt file (${DOWNLOADS_DIR}/texlive${TEXLIVE_VERSION}.iso) and execute the script again."
		exit 1
	else
		info "MD5 Verified."
	fi
fi

if [[ $MOUNT == "true" ]]; then
	if [[ $(id -u) -ne 0 ]]; then
		error "--mount needs root privilege. Try again with 'sudo -E'."
		exit 1
	fi
	# Reference: https://unix.stackexchange.com/a/151401
	info "Mount the ISO."
	mkdir -p ${DOWNLOADS_DIR}/texlive
	if ! mountpoint -q -- "${DOWNLOADS_DIR}/texlive"; then
		mount -r ${DOWNLOADS_DIR}/texlive${TEXLIVE_VERSION}.iso ${DOWNLOADS_DIR}/texlive
	fi
fi

if [[ $GENERATE_TEXLIVE_INSTALL_PROFILE == "true" ]]; then
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
	echo "${install_profile}" >>"${DOWNLOADS_DIR}/texlive.profile"
	info "TeXLive installation profile is saved to ${DOWNLOADS_DIR}/texlive.profile."
fi

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
	mkdir -p $(dirname ${filename})
	if [ ! -f "${filename}" ]; then
		wget_paths+=("${filename}")
		wget_urls+=("$url")
	fi
}
_wget_all() {
	for i in "${!wget_urls[@]}"; do
		wget "${wget_urls[i]}" -q -c --show-progress -O "${wget_paths[i]}"
	done
}
_download_everything() {
	# a wrapper of the function "wget_all"
	if [ ${#wget_urls[@]} = 0 ]; then
		debug "No download tasks."
	else
		debug "${#wget_urls[@]} files to download:"
		(
			IFS=$'\n'
			echo "${wget_urls[*]}"
		)
		_wget_all
	fi
}

if [[ ${DOWNLOAD_TYPEFACES} == "true" ]]; then
	TYPEFACES_DIR="${DOWNLOADS_DIR}/typefaces"
	mkdir -p ${TYPEFACES_DIR}

	_append_to_list 1 "https://github.com/adobe-fonts/source-han-serif/releases/download/2.002R/09_SourceHanSerifSC.zip" "${TYPEFACES_DIR}/SourceHanSerifSC/SourceHanSerifSC.zip"
	_append_to_list 1 "https://github.com/adobe-fonts/source-han-sans/releases/download/2.004R/SourceHanSansSC.zip" "${TYPEFACES_DIR}/SourceHanSansSC/SourceHanSansSC.zip"
	_append_to_list 1 "https://github.com/adobe-fonts/source-han-mono/releases/download/1.002/SourceHanMono.ttc" "${TYPEFACES_DIR}/SourceHanMono/SourceHanMono.ttc"
	_append_to_list 1 "https://github.com/adobe-fonts/source-serif/releases/download/4.005R/source-serif-4.005_Desktop.zip" "${TYPEFACES_DIR}/SourceSerif/SourceSerif.zip"
	_append_to_list 1 "https://github.com/adobe-fonts/source-sans/releases/download/3.052R/OTF-source-sans-3.052R.zip" "${TYPEFACES_DIR}/SourceSans/SourceSans.zip"
	_append_to_list 1 "https://github.com/adobe-fonts/source-code-pro/releases/download/2.042R-u%2F1.062R-i%2F1.026R-vf/OTF-source-code-pro-2.042R-u_1.062R-i.zip" "${TYPEFACES_DIR}/SourceCodePro/SourceCodePro.zip"
	_append_to_list 1 "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/SourceCodePro.zip" "${TYPEFACES_DIR}/NerdFontsSourceCodePro/NerdFontsSourceCodePro.zip"
	_append_to_list 1 "https://github.com/mozilla/Fira/archive/refs/tags/4.106.tar.gz" "${TYPEFACES_DIR}/FiraSans/FiraSans.tar.gz"
	_append_to_list 1 "https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip" "${TYPEFACES_DIR}/FiraCode/FiraCode.zip"
	_append_to_list 1 "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/FiraCode.zip" "${TYPEFACES_DIR}/NerdFontsFiraCode/NerdFontsSourceCodePro.zip"
	_append_to_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/adventor/qag2_501otf.zip" "${TYPEFACES_DIR}/TexGyreAdventor/TexGyreAdventor.zip"
	_append_to_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/bonum/qbk2.004otf.zip" "${TYPEFACES_DIR}/TexGyreBonum/TexGyreBonum.zip"
	_append_to_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/chorus/qzc2.003otf.zip" "${TYPEFACES_DIR}/TexGyreChorus/TexGyreChorus.zip"
	_append_to_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/cursor/qcr2.004otf.zip" "${TYPEFACES_DIR}/TexGyreCursor/TexGyreCursor.zip"
	_append_to_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/heros/qhv2.004otf.zip" "${TYPEFACES_DIR}/TexGyreHero/TexGyreHero.zip"
	_append_to_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/pagella/qpl2_501otf.zip" "${TYPEFACES_DIR}/TexGyrePagella/TexGyrePagella.zip"
	_append_to_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/schola/qcs2.005otf.zip" "${TYPEFACES_DIR}/TexGyreSchola/TexGyreSchola.zip"
	_append_to_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/termes/qtm2.004otf.zip" "${TYPEFACES_DIR}/TexGyreTermes/TexGyreTermes.zip"
	_append_to_list 1 "https://github.com/firamath/firamath/releases/download/v0.3.4/FiraMath-Regular.otf" "${TYPEFACES_DIR}/FiraMath/FiraMath-Regular.otf"

	_download_everything
fi

if [[ "$EXTRACT_TYPEFACES" = "true" ]]; then
	info "Extracting all the typefaces."
	# Reference: https://stackoverflow.com/a/2318189
	cd "$TYPEFACES_DIR"
	find . -name "*.tar.gz" | while read filename; do tar -zxf "$filename" --directory "$(dirname "$filename")"; done
	find . -name "*.zip" | while read filename; do unzip -qq -o -d "$(dirname "$filename")" "$filename"; done
fi

if [[ "$REMOVE_TYPEFACES_ZIPFILES" = "true" ]]; then
	cd "$TYPEFACES_DIR"
	find . \( -name "*.tar.gz" -o -name "*.zip" \) -exec rm {} +
fi
