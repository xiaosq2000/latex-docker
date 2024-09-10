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
    gnuplot-nox && \
    # Clear 
    rm -rf /var/lib/apt/lists/* && \
    # Set locales
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen

# Set the parent directory for all dependencies (not installed).
ARG XDG_PREFIX_DIR=/usr/local
ENV XDG_PREFIX_DIR=${XDG_PREFIX_DIR}

# Install TexLive
ARG TEXLIVE_VERSION
COPY downloads/texlive /texlive
COPY downloads/texlive.profile /texlive/texlive.profile
WORKDIR /texlive
RUN ./install-tl -profile=./texlive.profile
ENV PATH=${XDG_PREFIX_DIR}/texlive/${TEXLIVE_VERSION}/texmf-dist/doc/info:${PATH}
ENV PATH=${XDG_PREFIX_DIR}/texlive/${TEXLIVE_VERSION}/texmf-dist/doc/man:${PATH}
ENV PATH=${XDG_PREFIX_DIR}/texlive/${TEXLIVE_VERSION}/bin/x86_64-linux:$PATH

# Set up a non-root user within the sudo group.
ARG DOCKER_USER 
ARG DOCKER_UID
ARG DOCKER_GID 
ARG DOCKER_HOME=/home/${DOCKER_USER}
RUN groupadd -g ${DOCKER_GID} ${DOCKER_USER} && \
    useradd -r -m -d ${DOCKER_HOME} -s /bin/bash -g ${DOCKER_GID} -u ${DOCKER_UID} -G sudo ${DOCKER_USER} && \
    echo ${DOCKER_USER} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${DOCKER_USER} && \
    chmod 0440 /etc/sudoers.d/${DOCKER_USER}

# Zathura pdf viewer
# TODO: multistage build for build and runtime dependencies
RUN apt-get update && \
    apt-get install -qy --no-install-recommends \
    # basics 
    wget git unzip \
    gnupg2 dirmngr ca-certificates \
    # x11 client and dbus support
    xauth x11-apps xclip dbus dbus-x11 \
    # building
    build-essential cmake meson ninja-build \
    # forward and inverse searching
    libsynctex-dev \
    # xdg-open
    xdg-utils \
    # zathura compiling dependencies
    libgtk-3-dev libmagic-dev gettext libcanberra-gtk3-module libjson-glib-dev libsqlite3-dev \
    # Clear
    && rm -rf /var/lib/apt/lists/*

# TODO: Use ONBUILD instructions in Dockerfile to achieve conditonal building.

# Download zathura via package manager
RUN apt-get update && \
    apt-get install -qy --no-install-recommends \
    zathura zathura-dev \
    && rm -rf /var/lib/apt/lists/*

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

ENV PDFVIEWER=zathura

################################################################################
####################### Personal Development Environment #######################
################################################################################

USER ${DOCKER_USER}
WORKDIR ${DOCKER_HOME}

SHELL ["/bin/bash", "-c"]

ENV XDG_DATA_HOME=${DOCKER_HOME}/.local/share
ENV XDG_CONFIG_HOME=${DOCKER_HOME}/.config
ENV XDG_STATE_HOME=${DOCKER_HOME}/.local/state
ENV XDG_CACHE_HOME=${DOCKER_HOME}/.cache
ENV XDG_PREFIX_HOME=${DOCKER_HOME}/.local

# TODO: Manually build and install everything without sudo privilege
RUN sudo apt-get update && sudo apt-get install -qy --no-install-recommends \
    lsb-release \
    wget curl \
    zsh direnv \
    python3-venv python3-pip \
    openssh-server \
    ripgrep fd-find \
    && sudo rm -rf /var/lib/apt/lists/*

# Neovim
ARG NEOVIM_VERSION
RUN wget "https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/nvim-linux64.tar.gz" -O nvim-linux64.tar.gz && \
    tar -xf nvim-linux64.tar.gz && \
    export SOURCE_DIR=${PWD}/nvim-linux64 && export DEST_DIR=${XDG_PREFIX_HOME} && \
    (cd ${SOURCE_DIR} && find . -type f -exec install -Dm 755 "{}" "${DEST_DIR}/{}" \;) && \
    rm -r nvim-linux64.tar.gz nvim-linux64

# Tmux
ARG TMUX_GIT_HASH
RUN sudo apt-get update && sudo apt-get install -qy --no-install-recommends \
    libevent-dev ncurses-dev build-essential bison pkg-config autoconf automake \
    && sudo rm -fr /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/* && \
    git clone "https://github.com/tmux/tmux" && cd tmux && \
    git checkout ${TMUX_GIT_HASH} && \
    sh autogen.sh && \
    ./configure --prefix=${XDG_PREFIX_HOME} && \
    make -j ${COMPILE_JOBS} && \
    make install && \
    rm -rf ../tmux

RUN \
    # Install lazygit (the newest version)
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*') && \
    curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" && \
    tar xf lazygit.tar.gz lazygit && \
    install -Dm 755 lazygit ${XDG_PREFIX_HOME}/bin && \
    rm lazygit.tar.gz lazygit && \
    mkdir -p ${XDG_PREFIX_HOME}/bin && \
    # Install starship, a cross-shell prompt tool
    wget -qO- https://starship.rs/install.sh | sh -s -- --yes -b ${XDG_PREFIX_HOME}/bin && \
    # Install oh-my-zsh
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && \
    # Install tpm
    if [ -n ${http_proxy} && -n ${https_proxy} ]; then \
    git clone --config http.proxy=${http_proxy} --config https.proxy=${https_proxy} --depth 1 https://github.com/tmux-plugins/tpm ${XDG_PREFIX_HOME}/share/tmux/plugins/tpm; \
    else \
    git clone --depth 1 https://github.com/tmux-plugins/tpm ${XDG_PREFIX_HOME}/share/tmux/plugins/tpm; \
    fi && \
    # Install nvm, without modification of shell profiles
    export NVM_DIR=~/.config/nvm && mkdir -p ${NVM_DIR} && \
    PROFILE=/dev/null bash -c 'wget -qO- "https://github.com/nvm-sh/nvm/raw/master/install.sh" | bash' && \
    # Load nvm and install the latest lts nodejs
    . "${NVM_DIR}/nvm.sh" && nvm install --lts node

# Install mamba and conda
RUN cd ${XDG_PREFIX_HOME} && \
    curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba && \
    bin/micromamba config append channels conda-forge && \
    bin/micromamba config set channel_priority strict && \
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    bash Miniconda3-latest-Linux-x86_64.sh -b -p ${XDG_PREFIX_HOME}/miniconda3 && \
    rm Miniconda3-latest-Linux-x86_64.sh && \
    miniconda3/bin/conda config --set auto_activate_base false

# Set up ssh server
RUN sudo mkdir -p /var/run/sshd && \
    sudo sed -i "s/^.*X11UseLocalhost.*$/X11UseLocalhost no/" /etc/ssh/sshd_config && \
    sudo sed -i "s/^.*PermitUserEnvironment.*$/PermitUserEnvironment yes/" /etc/ssh/sshd_config

# A trick to get rid of using Docker building cache from now on.
ARG SETUP_TIMESTAMP
# Dotfiles
RUN cd ~ && \
    git init && \
    git remote add origin https://github.com/xiaosq2000/dotfiles && \
    git fetch --all && \
    git reset --hard origin/main && \
    git branch -M main

# Typefaces
RUN mkdir -p ${XDG_DATA_HOME}/fonts
COPY ./downloads/typefaces/ ${XDG_DATA_HOME}/fonts
RUN fc-cache -f

ENV TERM=xterm-256color
SHELL ["/usr/bin/zsh", "-ic"]
# RUN sudo chsh -s /usr/bin/zsh

# Clear environment variables exclusively for building to prevent pollution.
ENV DEBIAN_FRONTEND=newt
ENV http_proxy=
ENV HTTP_PROXY=
ENV https_proxy=
ENV HTTPS_PROXY=
