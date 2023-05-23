# contr

contr is a tool to create ad-hoc containers with limited access to the host system. By default, contr containers can only access the current working directory. Access to any other filesystem path must be given explicitly. Network access is blocked by default.

Under the hood, contr uses [Podman](https://podman.io/) to do the heavy lifting, and all options to [podman-run](https://docs.podman.io/en/latest/markdown/podman-run.1.html) are accepted.

Example uses:
* You cloned the git repository of a program you want to build, but you don't want `make` and other build scripts to have full access to your computer (even when not malicious, build scripts frequently have bugs. A `make clean` script accidentally erasing data elsewhere is a common issue). You can use contr to run the build inside a container.
  * contr itself is built inside a container like this!
* You want to run a program without installing it. Many programs offer a container option, but these containers are usually made by people with little experience with Linux containers, with long, convoluted and insecure instructions on how to use.
  * Take av1an's [docker instructions](https://github.com/master-of-zen/Av1an/blob/master/docs/DOCKER.md) for example. Running the same container under contr is not only safer, but also much simpler: `contr masterofzen/av1an:master av1an --help`  
  Alternatively, you can enter the container with `contr masterofzen/av1an:master`, and then run any commands inside it: `av1an --help`

## Usage
```
contr 0.2.0
Run container exposing the current working directory

Usage: contr [OPTION...] [PODMAN OPTIONS...] IMAGE [COMMAND [ARG...]]

Options:
  --make-config[=IMAGE]  Make example config files at CONTR_CONFIG_DIR. If optional IMAGE is provided, make per-image config files for that image instead of the global config files
  -n                     Allow network access
  --pio                  Per-Image Override: per-image config files override instead of adding to global config files. Useful when the per-image config conflicts with the global config
  --plain                Do not override the image's entrypoint script
  --pure                 Ignore all configuration files and custom entrypoint
  --help                 Print this help text and exit
  --help-all             Print this help text with all options to podman-run included and exit

Podman options:
  -*                     Any option for the podman-run command. Run 'contr --help-all' for a full list of options

Environment variables:
  CONTR_CONFIG_DIR        Configuration directory. Defaults to $XDG_CONFIG_HOME/contr or ~/.config/contr
  CONTR_ENVIRONMENT_FILE  Path to environment file. Defaults to $CONTR_CONFIG_DIR/environment
  CONTR_OPTIONS_FILE      Path to options file. Defaults to $CONTR_CONFIG_DIR/options
  CONTR_PROFILE_FILE      Path to profile file. Defaults to $CONTR_CONFIG_DIR/profile
  CONTR_STATE_DIR         State directory. Defaults to $XDG_STATE_HOME/contr or ~/.local/state/contr

Examples:
  contr alpine
  contr -n node:alpine
  contr --make-config=amazon/aws-cli
  contr -n --plain amazon/aws-cli --version
```

## Dependencies
contr depends on Podman and a POSIX-compliant shell with a few core utilities like `cat`, `chmod`, `grep`, `mkdir`, `tr` for operation.

The build process depends on `make`, `git` and a POSIX shell with basic core utilities like `cat`, `chmod`, `grep`, `date`, `mkdir`, `sed`, `tr`.

## Building and installing
A pre-built version is checked-in on the repository, at `dist/contr`. It can be easily installed with `make install` or, without make, a simple file copy to a directory in the PATH, for example `cp dist/contr ~/.local/bin/`.

We use the directory at `~/.local/bin` by default, as it is defined as a place for user-specific executable files in the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html) and should already be included in the PATH environment variable. If this directory is not present in the PATH, you can add it in your `~/.bashrc` (or similar) file. Pasting the following code will do it:
```shell
case ":${PATH}:" in
    *:"$HOME/.local/bin":*) ;;
    *) PATH="$HOME/.local/bin:$PATH" ;;
esac
```

To build and install into default PREFIX (`~/.local`):
```shell
make && make install
```

You can install into a different prefix by setting the PREFIX environment variable. For example, to install system-wide:
```shell
sudo make install PREFIX=/usr/local
```

To uninstall (also with optional PREFIX):
```shell
make uninstall

sudo make uninstall PREFIX=/usr/local
```

## Contributing
To develop contr we only depend on Podman and contr itself. We have a development container image with all the tools required to build and validate the project.

```
# Build the development image
podman build -f Containerfile.develop -t contr-develop

# Enter the development container
contr contr-develop

# Validate your changes for correctness
make lint

# Build contr
make
```

Every change must pass lint and formatting validation with `make lint`. As an option, formatting can be automatically applied with `make format`.

## License
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

See [UNLICENSE](UNLICENSE) file or http://unlicense.org/ for details.
