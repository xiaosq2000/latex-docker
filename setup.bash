#!/bin/bash
set -e
# ref: https://stackoverflow.com/a/246128
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# ref: https://askubuntu.com/a/970898
if ! [ $(id -u) = 0 ]; then
   echo "Error: The script need to be run as root." >&2
   exit 1
fi

################################################################################
###################### generate and load the '.env' file #######################
################################################################################
# Following environment varibles are used both in this script and variables 
# substitution of 'docker-compose.yml', taking effect in both image building 
# stage and runtime containers.
echo "
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
TEXLAB_VERSION=5.9.2
TMUX_VERSION=3.3a

DISPLAY=${DISPLAY}
" > ${SCRIPT_DIR}/.env

# ref: https://stackoverflow.com/a/30969768
set -o allexport
source ${SCRIPT_DIR}/.env
set +o allexport

# A small trick to append these four environment varibles to '.env' after
# sourcing, because these environment varibles are 
# 1. read-only varibles for bash that cannot be sourced
# 2. only needed for 'docker-compose.yml'
echo "
USER=${SUDO_USER}
UID=${SUDO_UID}
GID=${SUDO_GID}
HOME=/home/${SUDO_USER}
" >> ${SCRIPT_DIR}/.env

################################################################################
############################ download one huge iso #############################
################################################################################
if [ ! -f ${SCRIPT_DIR}/base/texlive${TEXLIVE_VERSION}.iso ]; then
    cd ${SCRIPT_DIR}/base
    wget https://ctan.mirrors.hoobly.com/systems/texlive/Images/\
texlive${TEXLIVE_VERSION}.iso
fi

################################################################################
################################# md5sum check #################################
################################################################################
MD5="`md5sum ${SCRIPT_DIR}/base/texlive${TEXLIVE_VERSION}.iso \
| awk '{ print $1 }'`"
REAL_MD5="`wget -qO- https://ctan.math.utah.edu/ctan/tex-archive/systems/\
texlive/Images/texlive${TEXLIVE_VERSION}.iso.md5 | awk '{ print $1 }'`"
if [ ${MD5} != ${REAL_MD5} ]; then
    echo "Error: ./base/texlive${TEXLIVE_VERSION}.iso MD5 checksum unverified" \
>&2
    exit 1
fi

################################################################################
################################ mount the iso #################################
################################################################################
if [ ! -d ${SCRIPT_DIR}/base/texlive ]; then
    mkdir -p ${SCRIPT_DIR}/base/texlive
fi

# ref: https://unix.stackexchange.com/a/151401
if [ ! $(mountpoint -q ${SCRIPT_DIR}/base/texlive) ]; then
    mount -r ${SCRIPT_DIR}/base/texlive${TEXLIVE_VERSION}.iso \
${SCRIPT_DIR}/base/texlive
fi

################################################################################
######################### generate the install profile #########################
################################################################################
# ref: https://www.tug.org/texlive/doc/install-tl.html#PROFILES
echo "selected_scheme scheme-${TEXLIVE_SCHEME}
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
tlpdbopt_w32_multi_user 1" > ${SCRIPT_DIR}/base/texlive.profile
