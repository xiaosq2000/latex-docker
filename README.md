# LaTeX in Docker

A dockerized LaTeX IDE for personal use, including [texlive](https://tug.org/texlive/), [zathura](https://pwmt.org/projects/zathura/), [neovim](https://neovim.io/), [tmux](https://github.com/tmux/tmux), [texlab](https://github.com/latex-lsp/texlab), [adobe fonts](https://github.com/adobe-fonts/) ...

## Quick Start

```sh
docker pull xiaosq2000/latex:latest
git clone git@github.com:xiaosq2000/latex-docker.git && cd latex-docker
python3 -m pip install -r requirements.txt
python3 generate_templates.py --env-file .env --service-name latex --nvidia --x11 --dbus --entrypoint
docker compose up -d 
docker exec -it latex zsh -i
```

<!--### 0. Requirements-->
<!---->
<!--[Docker Engine](https://docs.docker.com/engine/) and [Docker Compose](https://docs.docker.com/compose/)-->
<!---->
<!--### 1. Setup-->
<!---->
<!--#### 1.1 Run the setup script-->
<!---->
<!--```bash-->
<!--./setup.bash -h-->
<!--```-->
<!---->
<!--For a common user, get everything ready for the first time by executing-->
<!---->
<!--```bash-->
<!--sudo ./setup.bash --build --download_texlive --download_typefaces --extract_typefaces-->
<!--```-->
<!---->
<!--If using network proxy, modify related environment variables in setup.bash, and then-->
<!---->
<!--```bash-->
<!--sudo ./setup.bash --build --build_with_proxy --run_with_proxy --download_texlive --download_typefaces --extract_typefaces-->
<!--```-->
<!---->
<!--#### 1.2 Map your workspace-->
<!---->
<!--Modify the section `services.latex.volumes` in 'docker-compose.yml' to map your workspace directories in the host machine into the Docker container's file system.-->
<!---->
<!--### 2. Build & Run-->
<!---->
<!--```bash-->
<!--docker compose build && docker compose up -d-->
<!--```-->
<!---->
<!--### 3. Use it-->
<!---->
<!--```bash-->
<!--docker exec -it latex zsh-->
<!--```-->
