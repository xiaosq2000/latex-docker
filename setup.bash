#!/bin/bash

# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Arguments >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
TO_BUILD=true
BUILD_WITH_PROXY=true
RUN_WITH_PROXY=true
RUN_WITH_NVIDIA=true
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Arguments <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

# Be safe.
set -euo pipefail
# The parent folder of this script.
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# The default path of 'env_file' for Docker Compose and clear the file.
env_file=${script_dir}/.env && cat /dev/null > ${env_file}
# Check permission. Superuser privilege is used to mount the iso.
if ! [ $(id -u) = 0 ]; then
    echo "Error: The script needs root privilege to run. Try again with sudo." >&2
    exit 1
fi

# >>>>>>>>>>>>>>>>>>>>>>>>>> Environment Variables >>>>>>>>>>>>>>>>>>>>>>>>>>>>>
buildtime_env=$(cat <<-END

# >>> as 'service.build.args' in docker-compose.yml >>> 
DOCKER_BUILDKIT=1
BASE_IMAGE=ubuntu:22.04
TEXLIVE_VERSION=2023
TEXLIVE_SCHEME=full
GIRARA_VERSION=0.4.0
ZATHURA_VERSION=0.5.2
MUPDF_VERSION=1.22.0
ZATHURA_PDF_MUPDF_VERSION=0.4.0
NEOVIM_VERSION=0.9.4
TMUX_GIT_HASH=9ae69c3795ab5ef6b4d760f6398cd9281151f632
DOTFILES_GIT_HASH=a0e97bc323dfb0a915f667c6832130707eca512e
# <<< as 'service.build.args' in docker-compose.yml <<< 

END
)

buildtime_proxy_env=$(cat <<-END

BUILDTIME_NETWORK_MODE=host
# >>> as 'service.build.args' in docker-compose.yml >>> 
# Pay attention: 
# http_proxy: \${buildtime_http_proxy}
# ...
buildtime_http_proxy=http://127.0.0.1:1080
buildtime_https_proxy=http://127.0.0.1:1080
BUILDTIME_HTTP_PROXY=http://127.0.0.1:1080
BUILDTIME_HTTPS_PROXY=http://127.0.0.1:1080
# <<< as 'service.build.args' in docker-compose.yml <<< 

END
)
runtime_proxy_env=$(cat <<-END

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
user_env=$(cat <<-END

# >>> as 'service.build.args' in docker-compose.yml >>> 
DOCKER_USER=latex
DOCKER_HOME=/home/latex
DOCKER_UID=${SUDO_UID}
DOCKER_GID=${SUDO_GID}
# <<< as 'service.build.args' in docker-compose.yml <<< 

END
)
runtime_env=$(cat <<-END

RUNTIME=runc
DISPLAY=${DISPLAY}
SDL_VIDEODRIVER=x11

END
)
nvidia_runtime_env=$(cat <<-END

RUNTIME=nvidia
NVIDIA_VISIBLE_DEVICES=all
NVIDIA_DRIVER_CAPABILITIES=all
DISPLAY=${DISPLAY}
SDL_VIDEODRIVER=x11

END
)
# <<<<<<<<<<<<<<<<<<<<<<<<<< Environment Variables <<<<<<<<<<<<<<<<<<<<<<<<<<<<<

echo "
################################################################################
############################ Environment Variables #############################
################################################################################
" >> ${env_file}
echo "# The file is managed by 'setup.bash'." >> ${env_file}

# Verify and save the categories of environment variables.
if [ "${TO_BUILD}" = true ]; then
    echo "${buildtime_env}" >> ${env_file}
else
    echo -e "Warning: TO_BUILD=false\n\tMake sure the Docker image is ready."
fi
if [ "${BUILD_WITH_PROXY}" = true ]; then
    echo "${buildtime_proxy_env}" >> ${env_file}
else
    echo -e "Warning: BUILD_WITH_PROXY=false\n\tChinese GFW may corrupt networking in the building stage."
fi
if [ "${RUN_WITH_PROXY}" = true ]; then
    echo "${runtime_proxy_env}" >> ${env_file}
else
    echo -e "Warning: RUN_WITH_PROXY=false\n\tChinese GFW may corrupt networking."
fi
echo "${user_env}" >> ${env_file}
if [ "${RUN_WITH_NVIDIA}" = true ]; then
    echo "${nvidia_runtime_env}" >> ${env_file}
else
    echo "${runtime_env}" >> ${env_file}
fi
echo "
################################################################################
################################################################################
################################################################################
" >> ${env_file}
# Print the env_file to stdout
cat ${env_file}

# Load varibles from ${env_file}. Ref: https://stackoverflow.com/a/30969768
set -o allexport && source ${env_file} && set +o allexport

# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Downloads <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
# No need to download anything since the Docker image is ready.
if [ "${TO_BUILD}" = false ]; then
    exit 0
fi

downloads_dir="${script_dir}/downloads" && mkdir -p "${downloads_dir}"
                     
# Two helper functions for downloading.
wget_urls=(); wget_paths=();
append_to_download_list() {
    # $1: flag
    if [ -z "$(eval echo "\$$1")" ]; then
        return 0;
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
download_all() {
    for i in "${!wget_urls[@]}"; do
        wget "${wget_urls[i]}" -q --show-progress -O "${wget_paths[i]}"
    done
}

# Download TexLive (the huge iso distribution).
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

append_to_download_list GIRARA_VERSION "https://pwmt.org/projects/girara/download/girara-${GIRARA_VERSION}.tar.xz" ""
append_to_download_list ZATHURA_VERSION "https://pwmt.org/projects/zathura/download/zathura-${ZATHURA_VERSION}.tar.xz" ""
append_to_download_list MUPDF_VERSION "https://mupdf.com/downloads/archive/mupdf-${MUPDF_VERSION}-source.tar.gz" ""
append_to_download_list ZATHURA_PDF_MUPDF_VERSION "https://pwmt.org/projects/zathura-pdf-mupdf/download/zathura-pdf-mupdf-${ZATHURA_PDF_MUPDF_VERSION}.tar.xz" ""

# Typefaces
# Warning: Extract and organize them manually.
mkdir -p ${downloads_dir}/typefaces
mkdir -p ${downloads_dir}/typefaces/SourceHanSerifSC && append_to_download_list 1 "https://github.com/adobe-fonts/source-han-serif/releases/download/2.002R/09_SourceHanSerifSC.zip" "typefaces/SourceHanSerifSC/SourceHanSerifSC.zip"
mkdir -p ${downloads_dir}/typefaces/SourceHanSansSC && append_to_download_list 1 "https://github.com/adobe-fonts/source-han-sans/releases/download/2.004R/SourceHanSansSC.zip" "typefaces/SourceHanSansSC/SourceHanSansSC.zip"
mkdir -p ${downloads_dir}/typefaces/SourceHanMono && append_to_download_list 1 "https://github.com/adobe-fonts/source-han-mono/releases/download/1.002/SourceHanMono.ttc" "typefaces/SourceHanMono/SourceHanMono.ttc"
mkdir -p ${downloads_dir}/typefaces/SourceSerif && append_to_download_list 1 "https://github.com/adobe-fonts/source-serif/releases/download/4.005R/source-serif-4.005_Desktop.zip" "typefaces/SourceSerif/SourceSerif.zip"
mkdir -p ${downloads_dir}/typefaces/SourceSans && append_to_download_list 1 "https://github.com/adobe-fonts/source-sans/releases/download/3.052R/OTF-source-sans-3.052R.zip" "typefaces/SourceSans/SourceSans.zip"
mkdir -p ${downloads_dir}/typefaces/SourceCodePro && append_to_download_list 1 "https://github.com/adobe-fonts/source-code-pro/releases/download/2.042R-u%2F1.062R-i%2F1.026R-vf/OTF-source-code-pro-2.042R-u_1.062R-i.zip" "typefaces/SourceCodePro/SourceCodePro.zip"
mkdir -p ${downloads_dir}/typefaces/NerdFontsSourceCodePro && append_to_download_list 1 "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/SourceCodePro.zip" "typefaces/NerdFontsSourceCodePro/NerdFontsSourceCodePro.zip"
mkdir -p ${downloads_dir}/typefaces/FiraSans && append_to_download_list 1 "https://github.com/mozilla/Fira/archive/refs/tags/4.106.tar.gz" "typefaces/FiraSans/FiraSans.tar.gz"
mkdir -p ${downloads_dir}/typefaces/FiraCode && append_to_download_list 1 "https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip" "typefaces/FiraCode/FiraCode.zip"
mkdir -p ${downloads_dir}/typefaces/TexGyreAdventor && append_to_download_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/adventor/qag2_501otf.zip" "typefaces/TexGyreAdventor/TexGyreAdventor.zip"
mkdir -p ${downloads_dir}/typefaces/TexGyreBonum && append_to_download_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/bonum/qbk2.004otf.zip" "typefaces/TexGyreBonum/TexGyreBonum.zip"
mkdir -p ${downloads_dir}/typefaces/TexGyreChorus && append_to_download_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/chorus/qzc2.003otf.zip" "typefaces/TexGyreChorus/TexGyreChorus.zip"
mkdir -p ${downloads_dir}/typefaces/TexGyreCursor && append_to_download_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/cursor/qcr2.004otf.zip" "typefaces/TexGyreCursor/TexGyreCursor.zip"
mkdir -p ${downloads_dir}/typefaces/TexGyreHero && append_to_download_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/heros/qhv2.004otf.zip" "typefaces/TexGyreHero/TexGyreHero.zip"
mkdir -p ${downloads_dir}/typefaces/TexGyrePagella && append_to_download_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/pagella/qpl2_501otf.zip" "typefaces/TexGyrePagella/TexGyrePagella.zip"
mkdir -p ${downloads_dir}/typefaces/TexGyreSchola && append_to_download_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/schola/qcs2.005otf.zip" "typefaces/TexGyreSchola/TexGyreSchola.zip"
mkdir -p ${downloads_dir}/typefaces/TexGyreTermes && append_to_download_list 1 "https://www.gust.org.pl/projects/e-foundry/tex-gyre/termes/qtm2.004otf.zip" "typefaces/TexGyreTermes/TexGyreTermes.zip"

if [ ${#wget_urls[@]} = 0 ]; then
    echo -e "No download tasks. Done."
    exit;
else
    echo -e "${#wget_urls[@]} files to download:"
    (IFS=$'\n'; echo "${wget_urls[*]}")
fi

download_all;
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Downloads >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# install profile of texlive, Ref: https://www.tug.org/texlive/doc/install-tl.html#PROFILES
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
echo "# The file is managed by 'setup.bash'." > ${downloads_dir}/texlive.profile
echo "${install_profile}" >> ${downloads_dir}/texlive.profile
