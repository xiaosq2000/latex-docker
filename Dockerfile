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
    rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/* && \
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
    rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*

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

# Typefaces 
RUN mkdir -p /usr/local/share/fonts/
WORKDIR /usr/local/share/fonts/
COPY ./downloads/typefaces/FiraSans/Fira-4.106/otf/*.otf .
COPY ./downloads/typefaces/SourceSans/OTF/*.otf .
COPY ./downloads/typefaces/SourceSerif/source-serif-4.005_Desktop/OTF/*.otf .
COPY ./downloads/typefaces/SourceHanMono/SourceHanMono.ttc .
COPY ./downloads/typefaces/SourceHanSansSC/OTF/SimplifiedChinese/*.otf .
COPY ./downloads/typefaces/SourceHanSerifSC/OTF/SimplifiedChinese/*.otf .
COPY ./downloads/typefaces/SourceCodePro/OTF/*.otf .
COPY ./downloads/typefaces/NerdFontsSourceCodePro/*.ttf .
RUN \
    # Refresh fonts cache.
    fc-cache -fs && \
    # Generate the list of some available typefaces for convenience.
    mkdir -p ~/typefaces_lists && \
    fc-list -f "%{family}\n" | grep -i 'Source' > ~/typefaces_lists/adobe.txt && \
    fc-list -f "%{family}\n" | grep -i 'Fira' > ~/typefaces_lists/fira.txt && \
    fc-list -f "%{family}\n" :lang=zh-cn > ~/typefaces_lists/zh-cn.txt

################################################################################
####################### Personal Development Environment #######################
################################################################################
# Terminal: tmux (tpm)
# Shell: zsh (oh-my-zsh); starship
# Editor: neovim (packer, mason, nodejs)

ENV TERM=xterm-256color

RUN apt-get update && apt-get install -qy --no-install-recommends \
    curl wget \
    tmux \
    zsh \
    # nvim-telescope performance
    ripgrep fd-find \
    && rm -fr /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/* && \
    # Install starship, a cross-shell prompt tool
    wget -qO- https://starship.rs/install.sh | sh -s -- --yes

USER ${DOCKER_USER}
# Neovim
ARG NEOVIM_VERSION
ADD --chown=${DOCKER_USER}:${DOCKER_USER} https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/nvim-linux64.tar.gz ${DOCKER_HOME}/.local/nvim-linux64.tar.gz
RUN cd ~/.local/ && \
    tar -xf nvim-linux64.tar.gz && \
    mkdir -p ~/.local/bin/ ~/.local/lib/ && \
    mv nvim-linux64/bin/* ~/.local/bin/ && \
    mv nvim-linux64/lib/* ~/.local/lib/ && \
    rm -r nvim-linux64.tar.gz nvim-linux64

# Managers and plugins
RUN \
    # Install oh-my-zsh
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && \
    # Install zsh plugins
    git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting && \
    git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && \
    # Install packer.nvim
    git clone --depth 1 https://github.com/wbthomason/packer.nvim ~/.local/share/nvim/site/pack/packer/start/packer.nvim && \
    # Install tpm
    git clone --depth 1 https://github.com/tmux-plugins/tpm ~/.local/share/tmux/plugins/tpm && \
    # Install nvm, without modification of shell profiles
    export NVM_DIR=~/.config/nvm && mkdir -p ${NVM_DIR} && \
    PROFILE=/dev/null bash -c 'wget -qO- "https://github.com/nvm-sh/nvm/raw/master/install.sh" | bash' && \
    # Load nvm and install the latest lts nodejs
    . "${NVM_DIR}/nvm.sh" && nvm install --lts node

# Clear environment variables exclusively for building to prevent pollution.
ENV DEBIAN_FRONTEND=newt
ENV http_proxy=
ENV HTTP_PROXY=
ENV https_proxy=
ENV HTTPS_PROXY=

WORKDIR ${DOCKER_HOME}
