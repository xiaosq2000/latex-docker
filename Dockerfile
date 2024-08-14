# syntax=docker/dockerfile:1
ARG BASE_IMAGE
FROM ${BASE_IMAGE} as base
# Networking proxies
ARG http_proxy 
ARG HTTP_PROXY 
ARG https_proxy
ARG HTTPS_PROXY
ENV http_proxy ${http_proxy}
ENV HTTP_PROXY ${http_proxy}
ENV https_proxy ${http_proxy}
ENV HTTPS_PROXY ${http_proxy}
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
# Install TexLive
ARG TEXLIVE_VERSION
COPY downloads/texlive /texlive
COPY downloads/texlive.profile /texlive/texlive.profile
WORKDIR /texlive
RUN ./install-tl -profile=./texlive.profile
ENV PATH=/usr/local/texlive/${TEXLIVE_VERSION}/texmf-dist/doc/info:${PATH}
ENV PATH=/usr/local/texlive/${TEXLIVE_VERSION}/texmf-dist/doc/man:${PATH}
ENV PATH=/usr/local/texlive/${TEXLIVE_VERSION}/bin/x86_64-linux:$PATH
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
    build-essential \
    meson ninja-build \
    # zathura dependencies
    libgtk-3-dev libmagic-dev gettext libcanberra-gtk3-module \
    # forward and inverse searching
    libsynctex-dev \
    xdg-utils && \
    # Clear
    rm -rf /var/lib/apt/lists/*

# Set the parent directory for all dependencies (not installed).
ARG DEPENDENCIES_DIR=/usr/local
ENV DEPENDENCIES_DIR=${DEPENDENCIES_DIR}
WORKDIR ${DEPENDENCIES_DIR}

ARG GIRARA_VERSION
ADD downloads/girara-${GIRARA_VERSION}.tar.xz .
RUN cd girara-${GIRARA_VERSION} && \
    mkdir build && \
    meson build && \
    cd build && \
    ninja && \
    ninja install && \
    rm -r ../../girara-${GIRARA_VERSION}
ARG ZATHURA_VERSION=0.5.2
ADD downloads/zathura-${ZATHURA_VERSION}.tar.xz .
RUN cd zathura-${ZATHURA_VERSION} && \
    mkdir build && \
    meson build && \
    cd build && \
    ninja && \
    ninja install && \
    rm -r ../../zathura-${ZATHURA_VERSION}
ARG MUPDF_VERSION=1.22.0
ADD downloads/mupdf-${MUPDF_VERSION}-source.tar.gz .
RUN cd mupdf-${MUPDF_VERSION}-source && \
    make XCFLAGS='-fPIC' HAVE_X11=no HAVE_GLUT=no prefix=/usr/local install && \
    rm -r ../mupdf-${MUPDF_VERSION}-source
ARG ZATHURA_PDF_MUPDF_VERSION=0.4.0
ADD downloads/zathura-pdf-mupdf-${ZATHURA_PDF_MUPDF_VERSION}.tar.xz .
RUN cd zathura-pdf-mupdf-${ZATHURA_PDF_MUPDF_VERSION} && \
    mkdir build && \
    meson build && \
    cd build && \
    ninja && \
    ninja install && \
    rm -r ../../zathura-pdf-mupdf-${ZATHURA_PDF_MUPDF_VERSION}
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

# Set up ssh server
RUN sudo mkdir -p /var/run/sshd && \
    sudo sed -i "s/^.*X11UseLocalhost.*$/X11UseLocalhost no/" /etc/ssh/sshd_config && \
    sudo sed -i "s/^.*PermitUserEnvironment.*$/PermitUserEnvironment yes/" /etc/ssh/sshd_config

# Neovim
ARG NEOVIM_VERSION
RUN wget "https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/nvim-linux64.tar.gz" -O nvim-linux64.tar.gz && \
    tar -xf nvim-linux64.tar.gz && \
    export SOURCE_DIR=${PWD}/nvim-linux64 && export DEST_DIR=${HOME}/.local && \
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
    ./configure --prefix=${DOCKER_HOME}/.local && \
    make -j ${COMPILE_JOBS} && \
    make install && \
    rm -rf ../tmux

# Lazygit (newest version)
RUN LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*') && \
    curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" && \
    tar xf lazygit.tar.gz lazygit && \
    install -Dm 755 lazygit ${XDG_PREFIX_HOME}/bin && \
    rm lazygit.tar.gz lazygit

# Managers and plugins
RUN \
    # Install starship, a cross-shell prompt tool
    sudo apt-get update && sudo apt-get install -qy --no-install-recommends \
    musl-tools \
    && sudo rm -fr /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/* && \
    wget -qO- https://starship.rs/install.sh | sh -s -- --yes -b ${XDG_PREFIX_HOME}/bin && \
    # Install oh-my-zsh
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && \
    # Install tpm
    git clone --depth 1 https://github.com/tmux-plugins/tpm ${XDG_PREFIX_HOME}/share/tmux/plugins/tpm && \
    # Install nvm, without modification of shell profiles
    export NVM_DIR=~/.config/nvm && mkdir -p ${NVM_DIR} && \
    PROFILE=/dev/null bash -c 'wget -qO- "https://github.com/nvm-sh/nvm/raw/master/install.sh" | bash' && \
    # Load nvm and install the latest lts nodejs
    . "${NVM_DIR}/nvm.sh" && nvm install --lts node

# # Python
# RUN \
#     # Download the latest pyenv (python version and venv manager)
#     curl https://pyenv.run | bash && \
#     # Download the latest miniconda
#     mkdir -p ${XDG_PREFIX_HOME}/miniconda3 && \
#     wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ${XDG_PREFIX_HOME}/miniconda.sh && \
#     bash ${XDG_PREFIX_HOME}/miniconda.sh -b -u -p ${XDG_PREFIX_HOME}/miniconda3 && \
#     rm -rf ${XDG_PREFIX_HOME}/miniconda.sh && \
#     # Set up conda and pyenv, without conflicts, Ref: https://stackoverflow.com/a/58045893/11393911
#     # echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc && \
#     # echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc && \
#     # echo 'eval "$(pyenv init -)"' >> ~/.zshrc && \
#     cd ${XDG_PREFIX_HOME}/miniconda3/bin && \
#     # ./conda init zsh && \
#     ./conda config --set auto_activate_base false

# Dotfiles
# ARG DOTFILES_GIT_HASH
ARG SETUP_TIMESTAMP
RUN cd ~ && \
    git init && \
    git branch -M main && \
    git remote add origin https://github.com/xiaosq2000/dotfiles && \
    git fetch --all && \
    git reset --hard origin/main

SHELL ["/usr/bin/zsh", "-ic"]
ENV TERM=xterm-256color

# Micromamba
RUN cd ${XDG_PREFIX_HOME} && \
    # For Linux Intel (x86_64)
    curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba

# Typefaces
RUN mkdir -p ${XDG_DATA_HOME}/fonts
COPY ./downloads/typefaces/ ${XDG_DATA_HOME}/fonts
RUN fc-cache -f

# Clear environment variables exclusively for building to prevent pollution.
ENV DEBIAN_FRONTEND=newt
ENV http_proxy=
ENV HTTP_PROXY=
ENV https_proxy=
ENV HTTPS_PROXY=
