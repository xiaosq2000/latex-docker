# LaTex in docker

A dockerized LaTeX setup with lots of stuff, including [TexLive](https://tug.org/texlive/), [Zathura PDF Viewer](https://pwmt.org/projects/zathura/) ([MuPDF backend](https://pwmt.org/projects/zathura-pdf-mupdf/)), [NeoVim](https://neovim.io/), [tmux](https://github.com/tmux/tmux), [texlab](https://github.com/latex-lsp/texlab), [Adobe fonts](https://github.com/adobe-fonts/) ...

Already tested on Ubuntu 20.04, 22.04, 24.04.

## Quick Start

### 0. Requirements

[Docker Engine](https://docs.docker.com/engine/) and [Docker Compose](https://docs.docker.com/compose/)

### 1. Setup

```bash
./setup.bash -h
```

### 2. Build

```bash
docker compose build
```

### 3. Start

```bash
docker compose up -d
```

### 4. Use

```bash
docker exec -it latex bash
```
