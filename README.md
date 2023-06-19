# contr

contr (pronounced "conter") is a tool to create ad-hoc containers with limited access to the host system. By default, contr containers can only access the current working directory. Access to any other filesystem path must be given explicitly. Network access is blocked by default. Volumes are `noexec` by default, you have to explicitly add the `:exec` option to allow code execution from within a volume.

Under the hood, contr uses [Podman](https://podman.io/) to do the heavy lifting, and all options to [podman-run](https://docs.podman.io/en/latest/markdown/podman-run.1.html) are accepted.

## Why use contr

Here are some example use-cases of contr:

* You clone the git repository of a program you want to build, but you don't want `make` and other build scripts to have full access to all your data (even when not malicious, build scripts frequently have bugs. A `make clean` script accidentally erasing data elsewhere is a common issue). You can use contr to run the build inside a container.
  * contr itself is built inside a container like this!
* You want to run a CLI program without installing it on the host OS. Many programs offer a container option, but these are usually made by people with little experience with Linux containers, with long, convoluted and insecure instructions on how to use.
  * Take Av1an's [docker instructions](https://github.com/master-of-zen/Av1an/blob/master/docs/DOCKER.md) for example. Running the same container under contr is not only safer, but also much simpler: `contr masterofzen/av1an:master av1an --help`  
  Alternatively, you can enter the container with `contr masterofzen/av1an:master`, and then run any commands inside it: `av1an --help`
* You want to make it easier for your users to configure and build your software. Offer a container image with all build dependencies pre-installed, instead of filling your README file with build instructions for every OS under the sun. You likely already have such an image for CI purposes.
  * Just commit the Containerfile to the repository and `podman build -t my-develop-image`, and you're ready to use contr!

## Why not use Toolbx/Distrobox instead

Although contr fills some of the same use-cases of Toolbx/Distrobox, they are very different tools, trying to solve different problems. contr is a security tool, its purpose is to make computing safer. Toolbx/Distrobox can be seen as compatibility tools, they are a great way to bring the entire legacy of Linux distributions' packaging efforts into new immutable OSes. To achieve maximum compatibility with even GUI apps and system services, these tools expose the entire host OS to the container.

If you need a "pet" container to install all your programs inside, to update and change over time, to install and run GUI apps, or to install system management tools that need complete access to your computer, use Toolbx/Distrobox.

contr also brings most Linux distribution packages to any new Linux OS, but does so in a different way. In contr, images are pre-built with the software you need, usually from a recipe, like a [Containerfile](https://github.com/containers/common/blob/main/docs/Containerfile.5.md). Container images in contr should be limited in scope, you will usually have one image for each use-case. contr containers are not appropriate for installing more packages inside at runtime, these are not "pet" containers, they are transient, all changes are lost on exit.

For running CLI/TUI programs with limited access to your data, compiling and testing software (`make`, `npm install`, `cargo build`, etc.), or running scripts securely, use contr.

## Usage
```
contr 0.4.0
Run container exposing the current working directory

Usage:
  contr [OPTION...] [--] [PODMAN OPTIONS...] IMAGE [COMMAND [ARG...]]
  contr --make-config[=IMAGE]

Options:
  --make-config[=IMAGE]    Make example config files at CONTR_CONFIG_DIR. If optional IMAGE is provided, make per-image config files for that image instead of the global config files
  --cwd-mode=(0|4|5|6|7),
  --cwd-mode={ro,rw,exec}  The permission mode for mounting the current working directory inside the container. If set to 0, CWD will not be mounted inside the container. Numbers 4-7 have the same meanings as in chmod's octal values. Short flags exist for the octal form, as follows:
  -0                       Do not mount the current working directory inside the container '--cwd-mode=0'
  -4                       Mount the current working directory with read-only permissions '--cwd-mode=ro'
  -5                       Mount the current working directory with read and execute permissions '--cwd-mode=ro,exec'
  -6                       Mount the current working directory with read and write permissions '--cwd-mode=rw'
  -7                       Mount the current working directory with read, write and execute permissions (default) '--cwd-mode=rw,exec'
  -n                       Allow network access
  --pio                    Per-Image Override: per-image config files override instead of adding to global config files. Useful when the per-image config conflicts with the global config
  --plain                  Do not override the image's entrypoint script
  --pure                   Ignore all configuration files and custom entrypoint
  --help                   Print this help text and exit
  --help-all               Print this help text with all options to podman-run included and exit

Podman options:
  -*                       Any option for the podman-run command. Run 'contr --help-all' for a full list of options

Environment variables:
  CONTR_CONFIG_DIR   Configuration directory. Defaults to $XDG_CONFIG_HOME/contr or ~/.config/contr
  CONTR_RUNTIME_DIR  Runtime directory. Defaults to $XDG_RUNTIME_DIR/contr or /run/user/$UID/contr or /tmp/contr
  CONTR_DEBUG        Debug flags

Examples:
  contr alpine
  contr -n node:alpine sh
  contr --make-config=amazon/aws-cli
  contr -n amazon/aws-cli aws --version
```

## Main behavioral changes from Podman

* Current working directory is mounted by default. **Override**: `-0`
* Network access is blocked by default. **Override**: `-n`
* Volumes are `noexec` by default. **Override**: `:exec`
* Published ports are only bound to localhost by default. **Override**: `-p 0.0.0.0::PORT`
* When the host port is not specified, ports 1024 and above are published to the same port number on the host, instead of a random port.
* The latest image is pulled from the server on launch. **Override**: `--pull=never`
* The image's entrypoint script is replaced with contr's. **Override**: `--plain`

## Dependencies
contr depends on Podman and a POSIX-compatible shell with core utilities for operation.

## Installing
Download or clone this repository with git. The latest stable version is pre-built and checked-in on the repository at `dist/contr`. It can be easily installed with `./make install`, or a simple file copy to a directory in the PATH, for example `cp dist/contr ~/.local/bin/`.

```shell
# To install into default PREFIX (~/.local)
./make install

# To uninstall from default PREFIX
./make uninstall

# You can install into a different prefix by setting the PREFIX parameter
sudo ./make install PREFIX=/usr/local

# To uninstall from system PREFIX
sudo ./make uninstall PREFIX=/usr/local
```

We use the directory at `~/.local/bin` by default, as it is defined as a place for user-specific executable files in the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html) and should already be included in the PATH environment variable. If this directory is not present in the PATH, you can add it in your `~/.bashrc` (or similar) file. The following code does that:
```shell
case ":${PATH}:" in
    *:"${HOME}/.local/bin":*) ;;
    *) export PATH="${HOME}/.local/bin:${PATH}" ;;
esac
```

## Contributing
To develop contr we only depend on Podman and contr itself. We have a development container image with all the tools required to build and validate the project.

```shell
# Build the development image
podman build -f Containerfile.develop -t contr-develop

# Enter the development container
contr contr-develop

# Validate your changes for correctness
./make lint

# Build contr
./make
```

Every change must pass lint and formatting validation with `./make lint`. As an option, formatting can be automatically applied with `./make format`.

## License
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

See [UNLICENSE](UNLICENSE) file or http://unlicense.org/ for details.
