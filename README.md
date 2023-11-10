# LaTex in docker

A dockerized LaTeX setup with lots of stuff, including [TexLive](https://tug.org/texlive/), [Zathura PDF Viewer](https://pwmt.org/projects/zathura/) ([MuPDF backend](https://pwmt.org/projects/zathura-pdf-mupdf/)), [NeoVim](https://neovim.io/), [tmux](https://github.com/tmux/tmux), [texlab](https://github.com/latex-lsp/texlab), [Adobe fonts](https://github.com/adobe-fonts/) ... for personal use.

```bash
# a working tree for example
.
├── base
│   ├── Dockerfile
│   ├── .dockerignore
│   ├── texlive
│   ├── texlive2023.iso
│   └── texlive.profile
├── docker-compose.yml
├── Dockerfile
├── .dockerignore
├── .env
├── .gitignore
├── LICENSE
├── README.md
└── setup.bash

2 directories, 12 files
```

## Quick Start

### 0. Requirements

[Docker Engine](https://docs.docker.com/engine/) and [Docker Compose](https://docs.docker.com/compose/)

### 1. Setup

Run the `setup.bash` with superuser privilege.

```bash
sudo ./setup.bash
```

### 2. Build

```bash
docker compose build latex-base && docker compose build latex-dev
```

### 3. Start

```bash
docker compose up -d latex-dev
```

### 4. Use

```bash
docker exec -it latex_dev bash
```

## 
