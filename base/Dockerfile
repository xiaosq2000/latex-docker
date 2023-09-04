# syntax=docker/dockerfile:1

################################################################################
# install basic utilities via APT
################################################################################

ARG BASE_IMAGE
FROM ${BASE_IMAGE} as basic_utilities

RUN http_proxy=${http_proxy} \
    https_proxy=${https_proxy} \
    HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qy --no-install-recommends \
    # for downloading or building
    curl wget \
    unzip \
    git \
    ca-certificates gpg-agent \
    build-essential \
    # for x11 client and dbus support
    xauth x11-apps xclip dbus dbus-x11 \
    # for texlive tools
    fontconfig \
    perl \
    default-jre \
    libgetopt-long-descriptive-perl \
    libdigest-perl-md5-perl \
    libncurses6 \
    # for latexindent
    libunicode-linebreak-perl libfile-homedir-perl libyaml-tiny-perl \
    # for eps conversion
    ghostscript \
    # for metafont
    libsm6 \
    # for syntax highlighting
    python3 python3-pygments \
    # for gnuplot backend of pgfplots
    gnuplot-nox \ 
    # for Zathura pdf viewer
    meson ninja-build \
    libgtk-3-dev libmagic-dev gettext \
    libcanberra-gtk3-module \
    libsynctex-dev \
    && rm -rf /var/lib/apt/lists/*

################################################################################
# texlive
################################################################################

FROM basic_utilities as texlive

ARG TEXLIVE_VERSION
COPY ./texlive /texlive
COPY ./texlive.profile /texlive/texlive.profile
WORKDIR /texlive
RUN ./install-tl -profile=./texlive.profile

FROM basic_utilities
COPY --from=texlive /usr/local/ /usr/local/  
ARG TEXLIVE_VERSION
ENV PATH=/usr/local/texlive/${TEXLIVE_VERSION}/texmf-dist/doc/info:${PATH}
ENV PATH=/usr/local/texlive/${TEXLIVE_VERSION}/texmf-dist/doc/man:${PATH}
ENV PATH=/usr/local/texlive/${TEXLIVE_VERSION}/bin/x86_64-linux:$PATH

################################################################################
# zathura pdf viewer
################################################################################

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
