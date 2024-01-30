#!/bin/bash

# Be safe
set -euo pipefail
# Get parent folder of this script, a bash trick.
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# The path of 'env_file' for Docker Compose.
env_file=${script_dir}/.env 
# Clear env_file.
cat /dev/null > ${env_file}
# Check permission. Superuser privilege is used to mount the iso.
if ! [ $(id -u) = 0 ]; then
    echo "Error: The script needs root privilege to run. Try again with sudo." >&2
    exit 1
fi

# >>>>>>>>>>>>>>>>>>>>>>>>>> Environment Variables >>>>>>>>>>>>>>>>>>>>>>>>>>>>>

envs=$(cat <<-END
# building arguments
DOCKER_BUILDKIT=1
BASE_IMAGE=ubuntu:22.04
HTTP_PROXY=http://127.0.0.1:1080
HTTPS_PROXY=http://127.0.0.1:1080
http_proxy=http://127.0.0.1:1080
https_proxy=http://127.0.0.1:1080
TEXLIVE_VERSION=2023
TEXLIVE_SCHEME=full
GIRARA_VERSION=0.4.0
ZATHURA_VERSION=0.5.2
MUPDF_VERSION=1.22.0
ZATHURA_PDF_MUPDF_VERSION=0.4.0
NEOVIM_VERSION=0.9.1
DOCKER_USER=latex
DOCKER_HOME=/home/latex
DOCKER_UID=${SUDO_UID}
DOCKER_GID=${SUDO_GID}
#
NETWORK_MODE=host
DISPLAY=${DISPLAY}
END
)
# Write environment variables to file.
echo "${envs}" >> ${env_file}
# Load environment variables from file.
set -o allexport && source ${env_file} && set +o allexport

# <<<<<<<<<<<<<<<<<<<<<<<<<< Environment Variables <<<<<<<<<<<<<<<<<<<<<<<<<<<<<

downloads_dir=${script_dir}/downloads
mkdir -p ${downloads_dir}/

# Download TexLive (the huge iso distribution)
if [ ! -f ${downloads_dir}/texlive${TEXLIVE_VERSION}.iso ]; then
    wget https://ctan.mirrors.hoobly.com/systems/texlive/Images/texlive${TEXLIVE_VERSION}.iso -O ${downloads_dir}/texlive${TEXLIVE_VERSION}.iso
fi
# Check MD5.
md5="`md5sum ${downloads_dir}/texlive${TEXLIVE_VERSION}.iso | awk '{ print $1 }'`"
real_md5="`wget -qO- https://ctan.math.utah.edu/ctan/tex-archive/systems/texlive/Images/texlive${TEXLIVE_VERSION}.iso.md5 | awk '{ print $1 }'`"
if [ ${md5} != ${real_md5} ]; then
    echo "Error: MD5 checksum of texlive${TEXLIVE_VERSION}.iso is unverified" >&2
    exit 1
fi
echo "MD5 checksum of texlive${TEXLIVE_VERSION}.iso is verified."
# Mount the iso, Ref: https://unix.stackexchange.com/a/151401
mkdir -p ${downloads_dir}/texlive
if ! mountpoint -q -- "${downloads_dir}/texlive"; then
    mount -r ${downloads_dir}/texlive${TEXLIVE_VERSION}.iso ${downloads_dir}/texlive
fi
# Generate the install profile, Ref: https://www.tug.org/texlive/doc/install-tl.html#PROFILES
install_profile=$(cat <<-END
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
echo "${install_profile}" > ${downloads_dir}/texlive.profile

# Other dependencies.
wget_urls=(); wget_paths=();
# Two helper functions.
append_to_download_list() {
    if [ -z "$(eval echo "\$$1")" ]; then
        return 0;
    fi
    url="$2"
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
download_all() {
    for i in "${!wget_urls[@]}"; do
        wget "${wget_urls[i]}" -q --show-progress -O "${wget_paths[i]}"
    done
}

append_to_download_list GIRARA_VERSION "https://pwmt.org/projects/girara/download/girara-${GIRARA_VERSION}.tar.xz" ""
append_to_download_list ZATHURA_VERSION "https://pwmt.org/projects/zathura/download/zathura-${ZATHURA_VERSION}.tar.xz" ""
append_to_download_list MUPDF_VERSION "https://mupdf.com/downloads/archive/mupdf-${MUPDF_VERSION}-source.tar.gz" ""
append_to_download_list ZATHURA_PDF_MUPDF_VERSION "https://pwmt.org/projects/zathura-pdf-mupdf/download/zathura-pdf-mupdf-${ZATHURA_PDF_MUPDF_VERSION}.tar.xz" ""
append_to_download_list NEOVIM_VERSION "https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/nvim-linux64.tar.gz" ""

# Typefaces
# Extract manually.
mkdir -p ${downloads_dir}/typefaces
mkdir -p ${downloads_dir}/typefaces/SourceHanSerifSC
append_to_download_list 1 "https://github.com/adobe-fonts/source-han-serif/releases/download/2.002R/09_SourceHanSerifSC.zip" "typefaces/SourceHanSerifSC/SourceHanSerifSC.zip"
mkdir -p ${downloads_dir}/typefaces/SourceHanSansSC
append_to_download_list 1 "https://github.com/adobe-fonts/source-han-sans/releases/download/2.004R/SourceHanSansSC.zip" "typefaces/SourceHanSansSC/SourceHanSansSC.zip"
mkdir -p ${downloads_dir}/typefaces/SourceHanMono
append_to_download_list 1 "https://github.com/adobe-fonts/source-han-mono/releases/download/1.002/SourceHanMono.ttc" "typefaces/SourceHanMono/SourceHanMono.ttc"
mkdir -p ${downloads_dir}/typefaces/SourceSerif
append_to_download_list 1 "https://github.com/adobe-fonts/source-serif/releases/download/4.005R/source-serif-4.005_Desktop.zip" "typefaces/SourceSerif/SourceSerif.zip"
mkdir -p ${downloads_dir}/typefaces/SourceSans
append_to_download_list 1 "https://github.com/adobe-fonts/source-sans/releases/download/3.052R/OTF-source-sans-3.052R.zip" "typefaces/SourceSans/SourceSans.zip"
mkdir -p ${downloads_dir}/typefaces/SourceCodePro
append_to_download_list 1 "https://github.com/adobe-fonts/source-code-pro/releases/download/2.042R-u%2F1.062R-i%2F1.026R-vf/OTF-source-code-pro-2.042R-u_1.062R-i.zip" "typefaces/SourceCodePro/SourceCodePro.zip"
mkdir -p ${downloads_dir}/typefaces/NerdFontsSourceCodePro
append_to_download_list 1 "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/SourceCodePro.zip" "typefaces/NerdFontsSourceCodePro/NerdFontsSourceCodePro.zip"
mkdir -p ${downloads_dir}/typefaces/FiraSans
append_to_download_list 1 "https://github.com/mozilla/Fira/archive/refs/tags/4.106.tar.gz" "typefaces/FiraSans/FiraSans.tar.gz"

# Give some feedback via CLI.
if [ ${#wget_urls[@]} = 0 ]; then
    echo -e "No download tasks. Exiting now."
    echo "Done."
    exit;
else
    echo -e "${#wget_urls[@]} files to download:"
    (IFS=$'\n'; echo "${wget_urls[*]}")
fi

download_all;

echo "Done."
