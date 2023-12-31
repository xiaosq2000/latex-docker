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

FROM base AS building_tmux
ARG TMUX_VERSION
ADD downloads/tmux-${TMUX_VERSION}.tar.gz .
RUN apt-get update && apt-get install -qy --no-install-recommends \
    libevent-dev ncurses-dev bison \
    && rm -fr /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/* && \
    cd tmux-${TMUX_VERSION} && \
    mkdir -p build && \
    ./configure --prefix=${DEPENDENCIES_DIR}/tmux-${TMUX_VERSION}/build && \
    make -j ${COMPILE_JOBS} && make install
# Copy TMUX binaries.
FROM base
ARG TMUX_VERSION
RUN apt-get update && apt-get install -qy --no-install-recommends \
    # runtime dependencies
    libevent-core-2.1-7 libncurses6 \
    && rm -fr /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*
COPY --from=building_tmux --chown=${DOCKER_USER}:${DOCKER_USER} ${DEPENDENCIES_DIR}/tmux-${TMUX_VERSION}/build tmux-${TMUX_VERSION}
ENV PATH=${DEPENDENCIES_DIR}/tmux-${TMUX_VERSION}/bin:${PATH}
ENV LD_LIBRARY_PATH=${DEPENDENCIES_DIR}/tmux-${TMUX_VERSION}/lib:${LD_LIBRARY_PATH}
ENV MANPATH=${DEPENDENCIES_DIR}/tmux-${TMUX_VERSION}/share/man:${PATH}
# Copy pre-built neovim binaries.
ARG NEOVIM_VERSION
ADD downloads/nvim-linux64.tar.gz .
RUN apt-get update && apt-get install -qy --no-install-recommends \
    # for nvim-telescope better performance
    ripgrep fd-find \
    && rm -fr /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*
ENV PATH=${DEPENDENCIES_DIR}/nvim-linux64/bin:${PATH}

################################################################################
# Switch to non-root user from now on.
################################################################################

USER ${DOCKER_USER}

# Set up the default shell
SHELL ["/bin/bash", "-c"]
# Set up terminal related environment variables.
ENV TERM=xterm-256color
ENV color_prompt=yes

# My development environment
RUN \
    # Download packer.nvim, a neovim plugin manager.
    git config --global http.proxy ${http_proxy} && git config --global https.proxy ${https_proxy} && \
    git clone --config http.proxy=${http_proxy} --config https.proxy=${https_proxy} --depth 1 \
    https://github.com/wbthomason/packer.nvim \
    ${DOCKER_HOME}/.local/share/nvim/site/pack/packer/start/packer.nvim && \
    # Download tpm, a TMUX plugin manager.
    git clone --config http.proxy=${http_proxy} --config https.proxy=${http_proxy} \
    https://github.com/tmux-plugins/tpm \
    ${DOCKER_HOME}/.tmux/plugins/tpm && \
    # Download the latest nvm, a node-js version manager.
    wget -qO- "https://github.com/nvm-sh/nvm/raw/master/install.sh" | bash && \
    export NVM_DIR="$DOCKER_HOME/.nvm" && \
    # Configure the ~/.bashrc by executing this script.
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && \
    # Install the latest lts nodejs
    nvm install --lts node && \
    git config --global --unset http.proxy && git config --global --unset https.proxy

# Typefaces 
RUN mkdir -p ${DOCKER_HOME}/.local/share/fonts/
WORKDIR ${DOCKER_HOME}/.local/share/fonts/
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
    fc-cache -f && \
    # Generate the list of some available typefaces for convenience.
    mkdir -p ~/typefaces_lists && \
    fc-list -f "%{family}\n" | grep -i 'Source' > ~/typefaces_lists/adobe.txt && \
    fc-list -f "%{family}\n" | grep -i 'Fira' > ~/typefaces_lists/fira.txt && \
    fc-list -f "%{family}\n" :lang=zh-cn > ~/typefaces_lists/zh-cn.txt

WORKDIR ${DOCKER_HOME}

# Clear environment variables exclusively for building to prevent pollution.
ENV DEBIAN_FRONTEND=newt
ENV http_proxy=
ENV HTTP_PROXY=
ENV https_proxy=
ENV HTTPS_PROXY=
