# syntax=docker/dockerfile:1

ARG BASE_IMAGE
FROM ${BASE_IMAGE} AS base

################################################################################
######################### shell, terminal and locales ##########################
################################################################################
USER root

# shell
SHELL ["/bin/bash", "-c"]
# terminal
ENV TERM=xterm-256color
ENV color_prompt=yes
# locales, ref: https://help.ubuntu.com/community/Locale
RUN http_proxy=${http_proxy} \
    https_proxy=${https_proxy} \
    HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qy --no-install-recommends \
    locales \
    && rm -rf /var/lib/apt/lists/* && \
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen
ENV LC_ALL en_US.UTF-8 
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US

################################################################################
##################################### user #####################################
################################################################################
ARG UID 
ARG GID 
ARG USER 
RUN groupadd -g ${GID} ${USER} && \
    useradd -r -m -d /home/${USER} -s /bin/bash -g ${GID} -u ${UID} ${USER}
USER ${USER}
ARG HOME=/home/${USER}
WORKDIR ${HOME}

################################################################################
############################## Zathura pdf viewer ##############################
################################################################################
# TODO: multistage build for build and runtime dependencies
USER root
FROM base AS zathura
RUN http_proxy=${http_proxy} \
    https_proxy=${https_proxy} \
    HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qy --no-install-recommends \
    # for downloading
    wget \
    git \
    unzip \
    ca-certificates gpg-agent \
    # for x11 client and dbus support
    xauth x11-apps xclip dbus dbus-x11 \
    # for building
    build-essential \
    meson ninja-build \
    # zathura dependencies
    libgtk-3-dev libmagic-dev gettext libcanberra-gtk3-module \
    # forward and inverse searching
    libsynctex-dev \
    xdg-utils \ 
    && rm -rf /var/lib/apt/lists/*

ARG GIRARA_VERSION=0.4.0
ARG GIRARA_SRC_URL=https://pwmt.org/projects/girara/download/girara-${GIRARA_VERSION}.tar.xz
RUN wget -e http_proxy=${http_proxy} -e https_proxy=${https_proxy} ${GIRARA_SRC_URL} && \
    tar -xf girara-${GIRARA_VERSION}.tar.xz && \
    cd girara-${GIRARA_VERSION} && \
    mkdir build && \
    meson build && \
    cd build && \
    ninja && \
    ninja install && \
    rm -r ../../girara-${GIRARA_VERSION}.tar.xz ../../girara-${GIRARA_VERSION} 

ARG ZATHURA_VERSION=0.5.2
ARG ZATHURA_SRC_URL=https://pwmt.org/projects/zathura/download/zathura-${ZATHURA_VERSION}.tar.xz
RUN wget -e http_proxy=${http_proxy} -e https_proxy=${https_proxy} ${ZATHURA_SRC_URL} && \
    tar -xf zathura-${ZATHURA_VERSION}.tar.xz && \
    cd zathura-${ZATHURA_VERSION} && \
    mkdir build && \
    meson build && \
    cd build && \
    ninja && \
    ninja install && \
    rm -r ../../zathura-${ZATHURA_VERSION}.tar.xz ../../zathura-${ZATHURA_VERSION}

ARG MUPDF_VERSION=1.22.0
ARG MUPDF_SRC_URL=https://mupdf.com/downloads/archive/mupdf-${MUPDF_VERSION}-source.tar.gz
RUN wget -e http_proxy=${http_proxy} -e https_proxy=${https_proxy} ${MUPDF_SRC_URL} && \
    tar -zxf mupdf-${MUPDF_VERSION}-source.tar.gz && \
    cd mupdf-${MUPDF_VERSION}-source && \
    make XCFLAGS='-fPIC' HAVE_X11=no HAVE_GLUT=no prefix=/usr/local install && \
    rm ../mupdf-${MUPDF_VERSION}-source.tar.gz 

ARG ZATHURA_PDF_MUPDF_VERSION=0.4.0
ARG ZATHURA_PDF_MUPDF_SRC_URL=https://pwmt.org/projects/zathura-pdf-mupdf/download/zathura-pdf-mupdf-${ZATHURA_PDF_MUPDF_VERSION}.tar.xz
RUN wget -e http_proxy=${http_proxy} -e https_proxy=${https_proxy} ${ZATHURA_PDF_MUPDF_SRC_URL} && \
    tar -xf zathura-pdf-mupdf-${ZATHURA_PDF_MUPDF_VERSION}.tar.xz && \
    cd zathura-pdf-mupdf-${ZATHURA_PDF_MUPDF_VERSION} && \
    mkdir build && \
    meson build && \
    cd build && \
    ninja && \
    ninja install && \
    rm -r ../../zathura-pdf-mupdf-${ZATHURA_PDF_MUPDF_VERSION}.tar.xz ../../zathura-pdf-mupdf-${ZATHURA_PDF_MUPDF_VERSION}

ENV PDFVIEWER=zathura

################################################################################
#################################### editor ####################################
################################################################################
FROM zathura AS nvim
USER root
RUN http_proxy=${http_proxy} \
    https_proxy=${https_proxy} \
    HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qy --no-install-recommends \
    # for nvim-telescope better performance
    ripgrep \
    fd-find \
    # many nvim plugins and language servers are based on node-js and distributed via npm
    nodejs npm \
    && rm -rf /var/lib/apt/lists/*

ARG USER 
USER ${USER}
ARG HOME=/home/${USER}

ARG NEOVIM_VERSION=0.9.1
ARG NEOVIM_BIN_URL=https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/nvim-linux64.tar.gz
RUN wget -e http_proxy=${http_proxy} -e https_proxy=${https_proxy} ${NEOVIM_BIN_URL} && \
    tar -zxf nvim-linux64.tar.gz && \
    rm nvim-linux64.tar.gz && \
    mv nvim-linux64 ${HOME}/nvim-${NEOVIM_VERSION}
ENV PATH=${HOME}/nvim-${NEOVIM_VERSION}/bin:${PATH}
# neovim plugin manager
RUN git clone --config http.proxy=${http_proxy} --config https.proxy=${https_proxy} --depth 1 \
    https://github.com/wbthomason/packer.nvim \
    ~/.local/share/nvim/site/pack/packer/start/packer.nvim && \
    mkdir -p ${HOME}/.config/nvim
# pending for fetching plugins and mounting the configurations at runtime, since my setup is always WIP. only get packer.nvim (vim plugin manager) ready and mkdir $XDG_CONFIG_HOME/nvim

################################################################################
############################### language server ################################
################################################################################
# texlab
ARG TEXLAB_VERSION=5.9.2
ARG TEXLAB_BIN_URL=https://github.com/latex-lsp/texlab/releases/download/v${TEXLAB_VERSION}/texlab-x86_64-linux.tar.gz
RUN mkdir texlab-${TEXLAB_VERSION} && \
    cd texlab-${TEXLAB_VERSION} && \
    wget -e http_proxy=${http_proxy} -e https_proxy=${https_proxy} ${TEXLAB_BIN_URL} && \
    tar -zxf texlab-x86_64-linux.tar.gz && \
    rm texlab-x86_64-linux.tar.gz
ENV PATH=${HOME}/texlab-${TEXLAB_VERSION}/:${PATH}

################################################################################
##################################### tmux #####################################
################################################################################
FROM nvim AS tmux_build

# install dependencies via APT for building from source
USER root 
RUN http_proxy=${http_proxy} \
    https_proxy=${https_proxy} \
    HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qy --no-install-recommends \
    libevent-dev ncurses-dev build-essential bison pkg-config \
    && rm -rf /var/lib/apt/lists/*

# download, build, and install locally
ARG USER 
USER ${USER}
ARG HOME=/home/${USER}

ARG TMUX_VERSION=3.3a
ARG TMUX_SRC_URL=https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/tmux-${TMUX_VERSION}.tar.gz
RUN wget -e http_proxy=${http_proxy} -e https_proxy=${http_proxy} ${TMUX_SRC_URL} && \
    tar -zxf tmux-${TMUX_VERSION}.tar.gz && \
    rm tmux-${TMUX_VERSION}.tar.gz && \
    cd tmux-${TMUX_VERSION} && \
    mkdir build && \
    ./configure prefix=${HOME}/tmux-${TMUX_VERSION}/build && \
    make && \
    make install

FROM nvim AS tmux

USER root
RUN http_proxy=${http_proxy} \
    https_proxy=${https_proxy} \
    HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qy --no-install-recommends \
    # tmux runtime dependencies
    libevent-core-2.1-7 libncurses6 \
    && rm -rf /var/lib/apt/lists/*

ARG USER 
USER ${USER}
ARG HOME=/home/${USER}

ARG TMUX_VERSION=3.3a
COPY --from=tmux_build ${HOME}/tmux-${TMUX_VERSION}/build ${HOME}/tmux-${TMUX_VERSION}/build
ENV PATH=${HOME}/tmux-${TMUX_VERSION}/build/bin:${PATH}
ENV MANPATH=${HOME}/tmux-${TMUX_VERSION}/build/share/man:${MANPATH}

# tmux plugin manager
RUN git clone --config http.proxy=${http_proxy} --config https.proxy=${http_proxy} \
    https://github.com/tmux-plugins/tpm \
    ~/.tmux/plugins/tpm

################################################################################
################################## typefaces ###################################
################################################################################
RUN \
    # one of fontconfig default search paths
    mkdir -p ${HOME}/.local/share/fonts/adobe && cd ${HOME}/.local/share/fonts/adobe && \
    # source han serif (simpified chinese)
    mkdir source_han_serif && cd source_han_serif && \
    wget -e http_proxy=${http_proxy} -e https_proxy=${https_proxy} \ 
    https://github.com/adobe-fonts/source-han-serif/releases/download/2.002R/09_SourceHanSerifSC.zip && \
    unzip 09_SourceHanSerifSC.zip && rm 09_SourceHanSerifSC.zip && \
    cd ${HOME}/.local/share/fonts/adobe && \
    # source han sans (simpified chinese)
    mkdir source_han_sans && cd source_han_sans && \
    wget -e http_proxy=${http_proxy} -e https_proxy=${https_proxy} \ 
    https://github.com/adobe-fonts/source-han-sans/releases/download/2.004R/SourceHanSansSC.zip && \
    unzip SourceHanSansSC.zip && rm SourceHanSansSC.zip && \
    cd ${HOME}/.local/share/fonts/adobe && \
    # source han mono (super ttc, the only offical release, although only simpified chinese is needed for me.)
    mkdir source_han_mono && cd source_han_mono && \
    wget -e http_proxy=${http_proxy} -e https_proxy=${https_proxy} \ 
    https://github.com/adobe-fonts/source-han-mono/releases/download/1.002/SourceHanMono.ttc && \
    cd ${HOME}/.local/share/fonts/adobe && \
    # source serif
    mkdir source_serif && cd source_serif && \
    wget -e http_proxy=${http_proxy} -e https_proxy=${https_proxy} \ 
    https://github.com/adobe-fonts/source-serif/releases/download/4.005R/source-serif-4.005_Desktop.zip && \
    unzip source-serif-4.005_Desktop.zip && rm source-serif-4.005_Desktop.zip && \
    cd ${HOME}/.local/share/fonts/adobe && \
    # source sans
    mkdir source_sans && cd source_sans && \
    wget -e http_proxy=${http_proxy} -e https_proxy=${https_proxy} \ 
    https://github.com/adobe-fonts/source-sans/releases/download/3.052R/OTF-source-sans-3.052R.zip && \
    unzip OTF-source-sans-3.052R.zip && rm OTF-source-sans-3.052R.zip && \
    cd ${HOME}/.local/share/fonts/adobe && \
    # source code pro
    mkdir source_code_pro && cd source_code_pro && \
    wget -e http_proxy=${http_proxy} -e https_proxy=${https_proxy} \ 
    https://github.com/adobe-fonts/source-code-pro/releases/download/2.042R-u%2F1.062R-i%2F1.026R-vf/OTF-source-code-pro-2.042R-u_1.062R-i.zip && \
    unzip OTF-source-code-pro-2.042R-u_1.062R-i.zip && rm OTF-source-code-pro-2.042R-u_1.062R-i.zip && \
    # sauce code pro 
    # https://www.nerdfonts.com/ 
    cd ${HOME}/.local/share/fonts/ && mkdir -p nerdfonts && cd nerdfonts && \
    wget -e http_proxy=${http_proxy} -e https_proxy=${https_proxy} \ 
    https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/SourceCodePro.zip && \
    unzip SourceCodePro.zip && rm SourceCodePro.zip && \
    # fira
    cd ${HOME}/.local/share/fonts/ && mkdir -p fira && cd fira && \
    wget -e http_proxy=${http_proxy} -e https_proxy=${https_proxy} \
    https://github.com/mozilla/Fira/archive/refs/tags/4.106.tar.gz && \
    tar -zxf 4.106.tar.gz && \
    mv Fira-4.106/otf . && \
    rm -r 4.106.tar.gz Fira-4.106/ && \
    # refresh fonts cache
    fc-cache -f && \
    # for convenience
    fc-list -f "%{family}\n" | grep -i 'Source' > ~/adobe-typefaces.txt && \
    fc-list -f "%{family}\n" | grep -i 'Fira' > ~/fira-typefaces.txt && \
    fc-list -f "%{family}\n" :lang=zh-cn > ~/zh-cn-typefaces.txt
