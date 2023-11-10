# syntax=docker/dockerfile:1

ARG BASE_IMAGE
FROM ${BASE_IMAGE} as basic_utilities
RUN http_proxy=${http_proxy} \
    https_proxy=${https_proxy} \
    HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qy --no-install-recommends \
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
    && rm -rf /var/lib/apt/lists/*

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
