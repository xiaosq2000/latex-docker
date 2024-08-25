# LaTex in docker

A dockerized LaTeX setup with lots of stuff, including [TexLive](https://tug.org/texlive/), [Zathura PDF Viewer](https://pwmt.org/projects/zathura/) ([MuPDF backend](https://pwmt.org/projects/zathura-pdf-mupdf/)), [NeoVim](https://neovim.io/), [tmux](https://github.com/tmux/tmux), [texlab](https://github.com/latex-lsp/texlab), [Adobe fonts](https://github.com/adobe-fonts/) ...

Already tested on Ubuntu 20.04, 22.04, 24.04.

## Quick Start

### 0. Requirements

[Docker Engine](https://docs.docker.com/engine/) and [Docker Compose](https://docs.docker.com/compose/)

### 1. Setup

#### 1.1 Run the setup script

```bash
./setup.bash -h
```

For a common user, get everything ready for the first time by executing

```bash
sudo ./setup.bash --build --download_texlive --download_typefaces --extract_typefaces
```

If using network proxy, modify related environment variables in setup.bash, and then

```bash
sudo ./setup.bash --build --build_with_proxy --run_with_proxy --download_texlive --download_typefaces --extract_typefaces
```

#### 1.2 Map your workspace

Modify the section `services.latex.volumes` in 'docker-compose.yml' to map your workspace directories in the host machine into the Docker container's file system.

### 2. Build & Run

```bash
docker compose build && docker compose up -d
```

### 3. Use it

```bash
docker exec -it latex zsh
```
