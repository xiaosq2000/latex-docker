# syntax=docker/dockerfile:1
ARG BASE_IMAGE
FROM ${BASE_IMAGE} as base
# reference: https://askubuntu.com/a/1515958
RUN if [ $(cat /etc/os-release | grep '^NAME' | cut -d '=' -f 2) = '"Ubuntu"' ] && [ $(cat /etc/os-release | grep '^VERSION_ID' | cut -d '=' -f 2) = '"24.04"' ]; then touch /var/mail/ubuntu && chown ubuntu /var/mail/ubuntu && userdel -r ubuntu; fi
# Networking proxies
ARG buildtime_http_proxy 
ARG buildtime_https_proxy 
ENV http_proxy ${buildtime_http_proxy}
ENV HTTP_PROXY ${buildtime_http_proxy}
ENV https_proxy ${buildtime_https_proxy}
ENV HTTPS_PROXY ${buildtime_https_proxy}
# Avoid getting stuck with interactive interfaces when using apt-get
ENV DEBIAN_FRONTEND noninteractive
# Set the basic locale environment variables.
ENV LC_ALL en_US.UTF-8 
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US
RUN apt-get update && \
    apt-get install -qy --no-install-recommends \
    # basic utilities
    sudo locales \
    # texlive tools
    fontconfig \
    perl \
    default-jre \
    libgetopt-long-descriptive-perl \
    libdigest-perl-md5-perl \
    libncurses6 \
    # latexindent
    libunicode-linebreak-perl libfile-homedir-perl libyaml-tiny-perl \
    # eps conversion
    ghostscript \
    # metafont
    libsm6 \
    # syntax highlighting
    python3 python3-pygments \
    # gnuplot backend of pgfplots
    gnuplot-nox \
    # inkscape 
    inkscape \
    # zathura
    zathura zathura-dev \
    # Clear 
    && rm -rf /var/lib/apt/lists/* && \
    # Set locales
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen


# Set the parent directory for all dependencies (not installed).
ARG XDG_PREFIX_DIR=/usr/local
ENV XDG_PREFIX_DIR=${XDG_PREFIX_DIR}

# Set up a non-root user within the sudo group.
# Warning: 'sudo' is not recommended in Dockerfile.
ARG DOCKER_USER 
ARG DOCKER_UID
ARG DOCKER_GID 
ARG DOCKER_HOME
RUN groupadd -g ${DOCKER_GID} ${DOCKER_USER} && \
    useradd -r -m -d ${DOCKER_HOME} -s /bin/bash -g ${DOCKER_GID} -u ${DOCKER_UID} -G sudo ${DOCKER_USER} && \
    echo ${DOCKER_USER} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${DOCKER_USER} && \
    chmod 0440 /etc/sudoers.d/${DOCKER_USER}
USER ${DOCKER_USER}
SHELL ["/bin/bash", "-c"]

ENV XDG_DATA_HOME=${DOCKER_HOME}/.local/share
ENV XDG_CONFIG_HOME=${DOCKER_HOME}/.config
ENV XDG_STATE_HOME=${DOCKER_HOME}/.local/state
ENV XDG_CACHE_HOME=${DOCKER_HOME}/.cache
ENV XDG_PREFIX_HOME=${DOCKER_HOME}/.local

ENV PATH="${XDG_PREFIX_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${XDG_PREFIX_HOME}/lib:${PATH}"
ENV MAN_PATH="${XDG_PREFIX_HOME}/man:${PATH}"

# Install TexLive
ARG TEXLIVE_VERSION
COPY downloads/texlive /texlive
COPY downloads/texlive.profile /texlive/texlive.profile
WORKDIR /texlive
RUN sudo ./install-tl -profile=./texlive.profile
ENV PATH=${XDG_PREFIX_DIR}/texlive/${TEXLIVE_VERSION}/texmf-dist/doc/info:${PATH}
ENV PATH=${XDG_PREFIX_DIR}/texlive/${TEXLIVE_VERSION}/texmf-dist/doc/man:${PATH}
ENV PATH=${XDG_PREFIX_DIR}/texlive/${TEXLIVE_VERSION}/bin/x86_64-linux:$PATH

ENV PDFVIEWER=zathura

ARG COMPILE_JOBS

WORKDIR ${XDG_PREFIX_HOME}

RUN sudo apt-get update && sudo apt-get install -qy --no-install-recommends \
    wget curl unzip \
    git git-lfs neovim vim \
    build-essential autoconf cmake meson ninja-build \
    xauth x11-apps xclip \
    dbus dbus-x11 \
    xdg-utils xdotool \
    libsynctex-dev \
    && sudo rm -rf /var/lib/apt/lists/*

# Build & Install zsh
ARG ZSH_VERSION
RUN sudo apt-get update && sudo apt-get install -qy --no-install-recommends \
    libncurses-dev && \
    sudo rm -rf /var/lib/apt/lists/* && \
    wget https://downloads.sourceforge.net/project/zsh/zsh/${ZSH_VERSION}/zsh-${ZSH_VERSION}.tar.xz && \
    mkdir zsh-${ZSH_VERSION} && tar -xf zsh-${ZSH_VERSION}.tar.xz --strip-component=1 -C zsh-${ZSH_VERSION} && rm *.tar.xz && \
    cd zsh-${ZSH_VERSION} && \
    ./configure --prefix ${XDG_PREFIX_HOME} --with-term-lib="ncursesw" --with-tcsetpgrp && \
    make -j ${COMPILE_JOBS} && \
    make install 

# Neovim
ARG NEOVIM_VERSION
RUN if [ ! -z "${NEOVIM_VERSION}" ]; then \
    sudo apt-get update && sudo apt-get install -qy --no-install-recommends \
    fd-find ripgrep wl-clipboard && \
    sudo rm -rf /var/lib/apt/lists/* && \
    wget "https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/nvim-linux64.tar.gz" -O nvim-linux64.tar.gz && \
    tar -xf nvim-linux64.tar.gz && \
    export SRC_DIR="${PWD}/nvim-linux64" && export DEST_DIR="${XDG_PREFIX_HOME}" && \
    (cd ${SRC_DIR} && find . -type f -exec install -Dm 755 "{}" "${DEST_DIR}/{}" \;) && \
    rm -r nvim-linux64.tar.gz nvim-linux64 \
    ;else \
    sudo apt-get update && sudo apt-get install -qy --no-install-recommends \
    neovim \
    && sudo rm -fr /var/lib/apt/lists/* \
    ;fi

# Tmux
ARG TMUX_GIT_REFERENCE
RUN if [ ! -z "${TMUX_GIT_REFERENCE}" ]; then \
    sudo apt-get update && sudo apt-get install -qy --no-install-recommends \
    libevent-dev ncurses-dev build-essential bison pkg-config autoconf automake \
    && sudo rm -fr /var/lib/apt/lists/* && \
    git clone --config http.proxy=${http_proxy} --config https.proxy=${https_proxy} "https://github.com/tmux/tmux" && \ 
    cd tmux && \
    git checkout ${TMUX_GIT_REFERENCE} && \
    sh autogen.sh && \
    ./configure --prefix=${DOCKER_HOME}/.local && \
    make -j ${COMPILE_JOBS} && \
    make install && \
    rm -rf ../tmux \
    ;else \
    sudo apt-get update && sudo apt-get install -qy --no-install-recommends \
    tmux \
    && sudo rm -fr /var/lib/apt/lists/* \
    ;fi

# Install oh-my-zsh
RUN sudo apt-get update && sudo apt-get install -qy --no-install-recommends \
    python3-venv python3-pip && \
    sudo rm -rf /var/lib/apt/lists/* && \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install mamba and conda
RUN cd ${XDG_PREFIX_HOME} && \
    curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba && \
    bin/micromamba config append channels conda-forge && \
    bin/micromamba config set channel_priority strict && \
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    bash Miniconda3-latest-Linux-x86_64.sh -b -p ${XDG_PREFIX_HOME}/miniconda3 && \
    rm Miniconda3-latest-Linux-x86_64.sh && \
    miniconda3/bin/conda config --set auto_activate_base false

# Install msmtp
ARG MSMTP_VERSION
RUN if [[ ! -z "${MSMTP_VERSION}" ]]; then \
    sudo apt-get update && sudo apt-get install -qy --no-install-recommends \
    gettext autopoint gnutls-dev texinfo \
    && sudo rm -fr /var/lib/apt/lists/* && \
    wget https://github.com/marlam/msmtp/archive/refs/tags/msmtp-${MSMTP_VERSION}.tar.gz -O msmtp-${MSMTP_VERSION}.tar.gz && \
    mkdir msmtp-${MSMTP_VERSION} && tar -zxf msmtp-${MSMTP_VERSION}.tar.gz --strip-component=1 -C msmtp-${MSMTP_VERSION} && rm msmtp-${MSMTP_VERSION}.tar.gz && \
    cd msmtp-${MSMTP_VERSION} && \
    # ref: https://github.com/marlam/msmtp/issues/55#issuecomment-861797387
    # ref: https://lists.libreplanet.org/archive/html/bug-gettext/2011-12/msg00000.html
    export GETTEXT_MAJOR_VERSION=$(gettext --version | head -n 1 | awk '{ print $4; }' | cut -d "." -f "1") && \
    export GETTEXT_MINOR_VERSION=$(gettext --version | head -n 1 | awk '{ print $4; }' | cut -d "." -f "2") && \
    export GETTEXT_PATCH_VERSION=$(gettext --version | head -n 1 | awk '{ print $4; }' | cut -d "." -f "3") && \
    export LINE_NUMBER=$(grep -n 'AM_GNU_GETTEXT' ./configure.ac | cut -d':' -f1 | head -n1) && \
    sed -i "${LINE_NUMBER}i AM_GNU_GETTEXT_VERSION([${GETTEXT_MAJOR_VERSION}.${GETTEXT_MINOR_VERSION}.${GETTEXT_PATCH_VERSION}])" ./configure.ac && \
    autopoint -f && \
    autoreconf -i && \
    ./configure --prefix ${XDG_PREFIX_HOME} && \
    make && \
    make install \
    ; \
    else \
    sudo apt-get update && sudo apt-get install -qy --no-install-recommends \
    msmtp && \
    sudo rm -rf /var/lib/apt/lists/* \
    ; \
    fi

RUN sudo apt-get update && sudo apt-get install -qy --no-install-recommends \
    # gnome
    libnotify-bin \
    # vimtex
    psmisc \
    # google-drive-upload
    file \
    # pdfpc
    pdf-presenter-console gstreamer1.0-libav \
    && sudo rm -rf /var/lib/apt/lists/*

# set up ssh server
ARG SSH_PORT
RUN sudo apt-get update && sudo apt-get install -qy --no-install-recommends \
    openssh-server && \
    sudo rm -rf /var/lib/apt/lists/* && \
    sudo mkdir -p /var/run/sshd && \
    sudo sed -i "s/^.*X11UseLocalhost.*$/X11UseLocalhost no/" /etc/ssh/sshd_config && \
    sudo sed -i "s/^.*PermitUserEnvironment.*$/PermitUserEnvironment yes/" /etc/ssh/sshd_config && \
    sudo sed -i "s/^.*Port.*$/Port ${SSH_PORT}/" /etc/ssh/sshd_config

# Typefaces
RUN mkdir -p ${XDG_DATA_HOME}/fonts
COPY ./downloads/typefaces/ ${XDG_DATA_HOME}/fonts
RUN fc-cache -f

# a trick to get rid of using Docker building cache from now on.
ARG SETUP_FLAG

# dotfiles
RUN cd ~ && \
    git init && \
    git remote add origin https://github.com/xiaosq2000/dotfiles && \
    git fetch --all && \
    git reset --hard origin/main && \
    git branch -M main && \
    git branch -u origin/main main
# git submodule update --init 

# ENV TERM=screen-256color
ENV TERM=xterm-256color
SHELL ["zsh", "-ic"]
WORKDIR ${DOCKER_HOME}

# Clear environment variables exclusively for building to prevent pollution.
ENV DEBIAN_FRONTEND=newt
ENV http_proxy=
ENV HTTP_PROXY=
ENV https_proxy=
ENV HTTPS_PROXY=

################################################################################
################################### archive ####################################
################################################################################

# # Zathura pdf viewer
# # TODO: multistage build for build and runtime dependencies
# RUN apt-get update && \
#     apt-get install -qy --no-install-recommends \
#     # basics 
#     wget git unzip \
#     gnupg2 dirmngr ca-certificates \
#     # x11 client and dbus support
#     xauth x11-apps xclip dbus dbus-x11 \
#     # building
#     build-essential cmake meson ninja-build \
#     # forward and inverse searching
#     libsynctex-dev \
#     # xdg-open
#     xdg-utils \
#     # zathura compiling dependencies
#     libgtk-3-dev libmagic-dev gettext libcanberra-gtk3-module libjson-glib-dev libsqlite3-dev \
#     # Clear
#     && rm -rf /var/lib/apt/lists/*
# TODO: Use ONBUILD instructions in Dockerfile to achieve conditonal building.
# WORKDIR ${XDG_PREFIX_DIR}
#
# RUN if [[ -n ${TO_BUILD_ZATHURA} ]]; then \
#     apt-get update && \
#     apt-get install -qy --no-install-recommends \
#     libgtk-3-dev libmagic-dev gettext libcanberra-gtk3-module libjson-glib-dev libsqlite3-dev \
#     && rm -rf /var/lib/apt/lists/*; \
#     fi
# 
# ARG GIRARA_VERSION
# ADD downloads/girara-${GIRARA_VERSION}.tar.xz .
# RUN cd girara-${GIRARA_VERSION} && \
#     mkdir build && \
#     meson build && \
#     cd build && \
#     ninja && \
#     ninja install && \
#     rm -r ../../girara-${GIRARA_VERSION}
# 
# ARG ZATHURA_VERSION
# ADD downloads/zathura-${ZATHURA_VERSION}.tar.xz .
# RUN cd zathura-${ZATHURA_VERSION} && \
#     mkdir build && \
#     meson build && \
#     cd build && \
#     ninja && \
#     ninja install && \
#     rm -r ../../zathura-${ZATHURA_VERSION}
# 
# ARG MUPDF_VERSION
# ADD downloads/mupdf-${MUPDF_VERSION}-source.tar.gz .
# RUN cd mupdf-${MUPDF_VERSION}-source && \
#     make XCFLAGS='-fPIC' HAVE_X11=no HAVE_GLUT=no prefix=${XDG_PREFIX_DIR} install && \
#     rm -r ../mupdf-${MUPDF_VERSION}-source
# 
# ARG ZATHURA_PDF_MUPDF_VERSION
# ADD downloads/zathura-pdf-mupdf-${ZATHURA_PDF_MUPDF_VERSION}.tar.xz .
# RUN cd zathura-pdf-mupdf-${ZATHURA_PDF_MUPDF_VERSION} && \
#     mkdir build && \
#     meson build && \
#     cd build && \
#     ninja && \
#     ninja install && \
#     rm -r ../../zathura-pdf-mupdf-${ZATHURA_PDF_MUPDF_VERSION}
