import re
import os
import yaml
import argparse
from typing import Dict, Any
import psutil
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


def nested_set(dic: Dict[str, Any], keys: list, value: Any) -> None:
    for key in keys[:-1]:
        dic = dic.setdefault(key, {})
    dic[keys[-1]] = value


def manage_content_in_file(
    filename: str, content_to_manage: str | list, should_exist: bool
):
    file_lines = []
    content_found = False
    file_modified = False

    # Ensure content_to_manage is a list of strings
    if isinstance(content_to_manage, str):
        content_to_manage = [content_to_manage]

    try:
        # Read the file contents
        with open(filename, "r") as file:
            file_lines = file.readlines()

        # Strip newlines from content lines while preserving internal whitespace
        content_to_manage = [line.rstrip("\n") for line in content_to_manage]

        if len(content_to_manage) == 1:
            # Single line management
            for i, line in enumerate(file_lines):
                if line.rstrip("\n") == content_to_manage[0]:
                    content_found = True
                    if not should_exist:
                        del file_lines[i]
                        file_modified = True
                    break

            if should_exist and not content_found:
                file_lines.append(content_to_manage[0] + "\n")
                file_modified = True
        else:
            # Block management
            for i in range(len(file_lines) - len(content_to_manage) + 1):
                if [
                    line.rstrip("\n")
                    for line in file_lines[i : i + len(content_to_manage)]
                ] == content_to_manage:
                    content_found = True
                    if not should_exist:
                        del file_lines[i : i + len(content_to_manage)]
                        file_modified = True
                    break

            if should_exist and not content_found:
                file_lines.extend([line + "\n" for line in content_to_manage])
                file_modified = True

        # Write the modified content back to the file if changes were made
        if file_modified:
            with open(filename, "w") as file:
                file.writelines(file_lines)

            action = "added to" if should_exist else "removed from"
            content_type = "line" if len(content_to_manage) == 1 else "block of lines"
            logger.debug(f"The specified {content_type} was {action} the file.")
        else:
            state = "already exists in" if should_exist else "is not in"
            content_type = "line" if len(content_to_manage) == 1 else "block of lines"
            logger.debug(
                f"No changes made. The specified {content_type} {state} the file."
            )

    except FileNotFoundError:
        logger.error(f"File '{filename}' not found.")
    except IOError as e:
        logger.error(f"Unable to read or write file. {str(e)}")
    except Exception as e:
        logger.exception(f"An unexpected error occurred: {str(e)}")


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="""1. Generate template files (Docker Compose configuration, environment variables file, Docker entrypoint script...)
2. Generate build arguments in COMPOSE_FILE according to the ENV_FILE.
        """,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument(
        "--compose-file",
        type=str,
        default="./docker-compose.yml",
        help="Path to the Docker Compose file (default: %(default)s)",
    )

    parser.add_argument(
        "--env-file",
        type=str,
        default="./.env",
        help="Path to the environment variables file (default: %(default)s)",
    )

    parser.add_argument(
        "--service-name",
        type=str,
        required=True,
        help="Name of the service",
    )

    parser.add_argument(
        "--image",
        type=str,
        help="Name of the image (default: <SERVICE_NAME>:latest)",
    )

    parser.add_argument(
        "--container-name",
        type=str,
        help="Name of the container (default: <SERVICE_NAME>)",
    )

    parser.add_argument(
        "--generate-build-args",
        action="store_true",
        help="",
    )

    parser.add_argument(
        "--from-scratch",
        action="store_true",
        help="Clear the original docker-compose configuration.",
    )

    parser.add_argument(
        "--ipc-host",
        action="store_true",
        help="Reference: https://docs.docker.com/reference/cli/docker/container/run/#ipc",
    )

    parser.add_argument(
        "--privileged",
        action="store_true",
        help="Reference: https://docs.docker.com/engine/containers/run/#runtime-privilege-and-linux-capabilities",
    )

    parser.add_argument(
        "--nvidia",
        action="store_true",
        help="Enable NVIDIA GPU support for the specified service",
    )

    parser.add_argument(
        "--cpu-limit",
        type=float,
        default=os.cpu_count() / 2,
        help="""
        Set CPU usage limit for the service (e.g., 0.5 for half a CPU, 2 for two CPUs) 
        (default: %(default)s, half of the total resources on the host machine.)
        """,
    )

    parser.add_argument(
        "--memory-limit",
        type=str,
        default="{:.2f}G".format(psutil.virtual_memory().total / (1024**3) / 2),
        help="""
        Set memory usage limit for the service (e.g., 512M, 1G). 
        (default: %(default)s, half of the total resources on the host machine.)
        """,
    )

    parser.add_argument(
        "--cpu-reservation",
        type=float,
        default=os.cpu_count() / 16,
        help="""Set CPU reservation for the service (e.g., 0.1 for 10%% of a CPU, 1 for one full CPU)
        (default: %(default)s, 1/16 * total resources on the host machine.)
        """,
    )

    parser.add_argument(
        "--memory-reservation",
        type=str,
        default="{:.2f}G".format(psutil.virtual_memory().total / (1024**3) / 16),
        help="""Set memory reservation for the service (e.g., 256M, 1G)
        (default: %(default)s, 1/16 * total resources on the host machine.)
        """,
    )

    parser.add_argument(
        "--wayland",
        action="store_true",
        help="Set environment variables and mount socket related with Wayland",
    )

    parser.add_argument(
        "--x11",
        action="store_true",
        help="Set environment variables and mount socket related with X11",
    )

    parser.add_argument(
        "--dbus",
        action="store_true",
        help="Set environment variables and mount socket related with DBus",
    )

    parser.add_argument(
        "--x11-socket-volume",
        type=str,
        default="/tmp/.X11-unix:/tmp/.X11-unix:rw",
        help="(default: %(default)s)",
    )

    parser.add_argument(
        "--x11-authority-volume",
        type=str,
        # default="",
        # help="(default: %(default)s)",
    )

    parser.add_argument(
        "--wayland-volume",
        type=str,
        default="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$WAYLAND_DISPLAY:rw",
        help="(default: %(default)s)",
    )

    parser.add_argument(
        "--dbus-volume",
        type=str,
        default="/run/user/1000/bus:/run/user/1000/bus:rw",
        help="(default: %(default)s)",
    )

    parser.add_argument(
        "--volumes-append",
        type=str,
        nargs="+",
    )

    parser.add_argument(
        "--entrypoint",
        action="store_true",
        help="Use an external entrypoint shell script",
    )

    parser.add_argument(
        "--entrypoint-path",
        type=str,
        default="./entrypoint.sh",
        help="Path to the entrypoint shell script (default: %(default)s)",
    )

    args = parser.parse_args()
    return args


def generate_user_configuration(env_file, compose_data, service_name):
    manage_content_in_file(
        env_file,
        [
            "# User",
            f"# >>> as services.{service_name}.build.args",
            f"DOCKER_USER={service_name}",
            f"DOCKER_HOME=/home/{service_name}",
            f"DOCKER_UID={os.getuid()}",
            f"DOCKER_GID={os.getgid()}",
            f"# <<< as services.{service_name}.build.args",
        ],
        True,
    )
    nested_set(
        compose_data, ["services", service_name, "user"], "${DOCKER_UID}:${DOCKER_GID}"
    )


def generate_networking_configuration(env_file, compose_data, service_name):
    manage_content_in_file(
        env_file,
        [
            "# Networking",
            f"# >>> as services.{service_name}.build.args",
            "BUILDTIME_NETWORK_MODE=host",
            f"# <<< as services.{service_name}.build.args",
            "RUNTIME_NETWORK_MODE=host",
        ],
        True,
    )
    nested_set(
        compose_data,
        ["services", service_name, "build", "network"],
        "${BUILDTIME_NETWORK_MODE}",
    )
    nested_set(
        compose_data,
        ["services", service_name, "network_mode"],
        "${RUNTIME_NETWORK_MODE}",
    )
    nested_set(
        compose_data,
        ["services", service_name, "extra_hosts"],
        ["host.docker.internal:host-gateway"],
    )


def generate_entrypoint_template(entrypoint: str):
    with open(entrypoint, "w") as file:
        import subprocess

        user_name = subprocess.check_output(
            "git config --global user.name", shell=True, universal_newlines=True
        ).strip()
        user_email = subprocess.check_output(
            "git config --global user.email",
            shell=True,
            universal_newlines=True,
        ).strip()
        file.write(f"""#!/usr/bin/env bash
set -euo pipefail

has() {{
command -v "$1" 1>/dev/null 2>&1
}}

git config --global user.name "{user_name}"
git config --global user.email "{user_email}"

if [[ ! -f "/bin/zsh" && -f "${{XDG_PREFIX_HOME}}/bin/zsh" ]]; then
sudo ln -s "${{XDG_PREFIX_HOME}}/bin/zsh" /bin/zsh
fi

if [[ -z "$DBUS_SESSION_BUS_ADDRESS" ]]; then
if has "notify-send"; then
   notify-send "$(whoami) ready."
fi
fi

# sudo service ssh start

exec "$@"
""")


def generate_entrypoint_and_command(entrypoint_path, compose_data, service_name):
    volumes = compose_data["services"][service_name]["volumes"]
    volumes.append(f"{entrypoint_path}:/entrypoint.sh:ro")
    logger.debug(f"Added a new volume '{entrypoint_path}:/entrypoint.sh:ro'")
    logger.debug("Added entrypoint with 'zsh -i'")
    nested_set(
        compose_data,
        ["services", service_name, "entrypoint"],
        ["zsh", "-i", "/entrypoint.sh"],
    )
    if not os.path.exists(entrypoint_path):
        generate_entrypoint_template(entrypoint_path)
    nested_set(
        compose_data,
        ["services", service_name, "command"],
        ["zsh", "-i"],
    )


def generate_build_args(compose_file: str, env_file: str, service_name: str):
    # Load the docker-compose.yml file
    with open(compose_file, "r") as file:
        compose_data = yaml.safe_load(file)

    # Read the contents of the bash script
    with open(env_file, "r") as file:
        bash_content = file.read()

    # Extract all build argument names from the bash script based on the specified rule
    build_args_pattern = re.compile(
        r"# >>> as services\.{service}\.build\.args\s*(.*?)\s*# <<< as services\.{service}\.build\.args".format(
            service=re.escape(service_name)
        ),
        re.DOTALL,
    )
    build_args_matches = build_args_pattern.findall(bash_content)

    build_args = {}
    for match in build_args_matches:
        build_args_content = match.strip()
        for line in build_args_content.split("\n"):
            line = line.strip()
            if line and not line.startswith("#"):
                key, value = line.split("=", 1)
                build_args[key] = f"${{{key}}}"

    if not build_args:
        logger.warning(
            """No build arguments found in the shell script '{}' for service '{}'.
Please make sure the bash script contains the following lines:
# >>> as services.{}.build.args
# ENV_VAR_1=value1
# ENV_VAR_2=value2
# ...
# <<< as services.{}.build.args
Skipping the update of docker-compose.yml.
""".format(env_file, service_name, service_name, service_name)
        )
        exit(0)

    # Update the build section in the docker-compose.yml file
    build = compose_data["services"][service_name]["build"]
    build["args"] = build_args

    # Save the updated docker-compose.yml file
    with open(compose_file, "w") as file:
        yaml.dump(compose_data, file, default_flow_style=False)


def generate_basic_configuration(
    args: Any, env_file: str, service_name: str, compose_data: Dict
):
    nested_set(compose_data, ["services", service_name, "env_file"], env_file)
    manage_content_in_file(
        env_file,
        [
            f"# >>> as services.{service_name}.build.args",
            "DOCKER_BUILDKIT=1",
            f"# <<< as services.{service_name}.build.args",
        ],
        True,
    )
    nested_set(compose_data, ["services", service_name, "build", "context"], ".")
    nested_set(
        compose_data, ["services", service_name, "build", "dockerfile"], "Dockerfile"
    )
    nested_set(compose_data, ["services", service_name, "restart"], "always")
    nested_set(compose_data, ["services", service_name, "stdin_open"], True)
    nested_set(compose_data, ["services", service_name, "tty"], True)

    if args.privileged:
        nested_set(compose_data, ["services", service_name, "privileged"], True)

    if args.ipc_host:
        nested_set(compose_data, ["services", service_name, "ipc"], "host")

    # Add CPU and memory resources configuration
    nested_set(
        compose_data["services"][args.service_name],
        ["deploy", "resources", "limits", "cpus"],
        args.cpu_limit,
    )
    logger.debug(
        f"Setting CPU limit to {args.cpu_limit} for service '{args.service_name}'"
    )

    nested_set(
        compose_data["services"][args.service_name],
        ["deploy", "resources", "limits", "memory"],
        args.memory_limit,
    )
    logger.debug(
        f"Setting memory limit to {args.memory_limit} for service '{args.service_name}'"
    )

    if args.cpu_reservation is not None:
        nested_set(
            compose_data["services"][args.service_name],
            ["deploy", "resources", "reservations", "cpus"],
            args.cpu_reservation,
        )
        logger.debug(
            f"Setting CPU reservation to {args.cpu_reservation} for service '{args.service_name}'"
        )

    if args.memory_reservation is not None:
        nested_set(
            compose_data["services"][args.service_name],
            ["deploy", "resources", "reservations", "memory"],
            args.memory_reservation,
        )
        logger.debug(
            f"Setting memory reservation to {args.memory_reservation} for service '{args.service_name}'"
        )
    # Name of the image and container
    image = args.image if args.image is not None else f"{args.service_name}:latest"
    nested_set(compose_data, ["services", service_name, "image"], image)
    container_name = (
        args.container_name
        if args.container_name is not None
        else f"{args.service_name}"
    )
    nested_set(
        compose_data, ["services", service_name, "container_name"], container_name
    )


def generate_nvidia_configuration(
    env_file: str, compose_data: Dict, service_name: str, nvidia: bool
):
    # Add NVIDIA GPU configuration if requested
    manage_content_in_file(
        env_file,
        ["NVIDIA_VISIBLE_DEVICES=all", "NVIDIA_DRIVER_CAPABILITIES=all"],
        nvidia,
    )

    if nvidia:
        logger.debug(f"Use nvidia container runtime for service '{service_name}'.")

        nested_set(
            compose_data["services"][service_name],
            ["runtime"],
            "nvidia",
        )

        logger.debug(
            f"Deploy all NVIDIA GPU Devices with GPU capabilities for service '{service_name}'."
        )

        nested_set(
            compose_data["services"][service_name],
            ["deploy", "resources", "reservations", "devices"],
            [{"capabilities": ["gpu"], "count": "all", "driver": "nvidia"}],
        )


def generate_wayland_configuration(
    compose_data,
    env_file,
    service_name,
    wayland,
    wayland_volume="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$WAYLAND_DISPLAY:rw",
):
    volumes = compose_data["services"][service_name]["volumes"]
    # Handle Wayland socket mounting
    manage_content_in_file(env_file, 'WAYLAND_DISPLAY="${WAYLAND_DISPLAY}"', wayland)
    if wayland:
        if wayland_volume not in volumes:
            volumes.append(wayland_volume)
            logger.debug(f"Added Wayland socket mount for service '{service_name}'")
    else:
        if wayland_volume in volumes:
            volumes.remove(wayland_volume)
            logger.debug(f"Removed Wayland socket mount from service '{service_name}'")


def generate_x11_configuration(
    compose_data,
    env_file,
    service_name,
    x11,
    x11_socket_volume,
    x11_authority_volume,
):
    volumes = compose_data["services"][service_name]["volumes"]
    # Handle X11 socket mounting
    manage_content_in_file(env_file, 'DISPLAY="${DISPLAY}"', x11)
    manage_content_in_file(env_file, 'XAUTHORITY="${XAUTHORITY}"', x11)

    if x11_authority_volume is None:
        x11_authority_file = os.environ.get("XAUTHORITY")
        if x11_authority_file is None:
            logger.error("X11 authority file is not given.")
        else:
            x11_authority_volume = f"{x11_authority_file}:{x11_authority_file}:rw"

    if x11:
        if x11_socket_volume not in volumes:
            volumes.append(x11_socket_volume)
            logging.debug(f"Added X11 socket mount for service '{service_name}'")
            if x11_authority_volume is not None:
                volumes.append(x11_authority_volume)
                logging.debug(
                    f"Added X11 authority file mount for service '{service_name}'"
                )
        # Reference: https://github.com/mviereck/x11docker/wiki/Short-setups-to-provide-X-display-to-container
        logging.debug("Using host IPC")
        compose_data["services"][service_name]["ipc"] = "host"
    else:
        if x11_socket_volume in volumes:
            volumes.remove(x11_socket_volume)
            logging.debug(f"Removed X11 socket mount from service '{service_name}'")
            volumes.remove(x11_authority_volume)
            logging.debug(
                f"Removed X11 authority file mount from service '{service_name}'"
            )


# TODO
def generate_default_volume_configuration(compose_data, service_name):
    # Handle volumes
    nested_set(
        compose_data,
        ["services", service_name, "volumes"],
        [
            "~/Projects:${DOCKER_HOME}/Projects:rw",
            "~/Documents:${DOCKER_HOME}/Documents:rw",
            "~/Datasets:${DOCKER_HOME}/Datasets:rw",
            "~/Pictures:${DOCKER_HOME}/Pictures:rw",
            "~/Videos:${DOCKER_HOME}/Videos:rw",
            "~/.ssh:${DOCKER_HOME}/.ssh:ro",
            f"{os.environ.get("XDG_RUNTIME_DIR")}:{os.environ.get("XDG_RUNTIME_DIR")}:rw"
        ],
    )


def generate_dbus_configuration(
    compose_data, service_name, env_file, dbus, dbus_volume=""
):
    # Handle DBus socket mounting
    volumes = compose_data["services"][service_name]["volumes"]
    manage_content_in_file(
        env_file,
        'DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS"',
        dbus,
    )
    if dbus:
        nested_set(compose_data, ["services", service_name, "privileged"], True)
        if dbus_volume not in volumes:
            volumes.append(dbus_volume)
            logger.debug(f"Added DBus socket mount for service '{service_name}'")
    else:
        if dbus_volume in volumes:
            volumes.remove(dbus_volume)
            logger.debug(f"Removed DBus socket mount from service '{service_name}'")


def main():
    args = parse_arguments()

    env_file = args.env_file
    compose_file = args.compose_file
    service_name = args.service_name

    compose_file_from_scratch = args.from_scratch or not os.path.exists(compose_file)

    compose_data = (
        {} if compose_file_from_scratch else yaml.safe_load(open(compose_file, "r"))
    )

    if args.generate_build_args:
        generate_build_args(
            env_file=env_file, compose_file=compose_file, service_name=service_name
        )
        logger.debug(
            "Generate build args in Docker Compose file according to environment variables file."
        )
        exit(0)

    env_file_from_scratch = args.from_scratch or not os.path.exists(env_file)

    start_line_env_file = """# >>> auto-generated contents
"""
    end_line_env_file = """# <<< auto-generated contents
"""

    if not env_file_from_scratch:
        with open(env_file, "r") as file:
            env_file_other_contents = []
            is_managed_content = False
            for line in file:
                if line == start_line_env_file:
                    is_managed_content = True
                    continue
                elif line == end_line_env_file:
                    is_managed_content = False
                    continue
                elif not is_managed_content:
                    env_file_other_contents.append(line)

    with open(env_file, "w") as file:
        file.write(start_line_env_file)

    generate_basic_configuration(
        service_name=service_name,
        compose_data=compose_data,
        env_file=env_file,
        args=args,
    )

    generate_user_configuration(
        service_name=service_name,
        compose_data=compose_data,
        env_file=env_file,
    )

    generate_default_volume_configuration(
        service_name=service_name,
        compose_data=compose_data,
    )

    generate_networking_configuration(
        service_name=service_name,
        compose_data=compose_data,
        env_file=env_file,
    )

    generate_nvidia_configuration(
        service_name=service_name,
        compose_data=compose_data,
        env_file=env_file,
        nvidia=args.nvidia,
    )

    generate_wayland_configuration(
        service_name=service_name,
        compose_data=compose_data,
        env_file=env_file,
        wayland=args.wayland,
        wayland_volume=args.wayland_volume,
    )

    generate_x11_configuration(
        service_name=service_name,
        compose_data=compose_data,
        env_file=env_file,
        x11=args.x11,
        x11_socket_volume=args.x11_socket_volume,
        x11_authority_volume=args.x11_authority_volume,
    )

    generate_dbus_configuration(
        service_name=service_name,
        compose_data=compose_data,
        env_file=env_file,
        dbus=args.dbus,
        dbus_volume=args.dbus_volume,
    )

    if args.volumes_append is not None:
        for item in args.volumes_append:
            logger.debug(f"Added a new volume '{item}'")
            compose_data["services"][service_name]["volumes"].append(item)

    if args.entrypoint:
        generate_entrypoint_and_command(
            service_name=service_name,
            compose_data=compose_data,
            entrypoint_path=args.entrypoint_path,
        )

    with open(env_file, "a") as file:
        file.write(end_line_env_file)
        if not env_file_from_scratch:
            for line in env_file_other_contents:
                file.write(line)

    with open(compose_file, "w") as file:
        yaml.dump(compose_data, file)


if __name__ == "__main__":
    main()
