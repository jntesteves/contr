# contr

Run container exposing the current working directory

## Usage
```
contr 0.1.1-pre
Run container exposing the current working directory

Usage: contr [OPTION...] [PODMAN OPTIONS...] IMAGE [COMMAND [ARG...]]

Options:
  --make-config[=IMAGE]  Make example config files at CONTR_CONFIG_DIR. If optional IMAGE is provided, make per-image config files for that image instead of the global config files
  --pio                  Per-Image Override: per-image config files override instead of adding to global config files. Useful when the per-image config conflicts with the global config
  --plain                Do not override the image's entrypoint script
  --pure                 Ignore all configuration files and the entrypoint
  --help                 Print this help text and exit
  --help-all             Print this help text with all options to "podman run" included and exit

Podman options:
  -*                     Any option for the 'podman run' command. Run 'contr --help-all' for a full list of options

Environment variables:
  CONTR_CONFIG_DIR        Configuration directory. Defaults to $XDG_CONFIG_HOME/contr or ~/.config/contr
  CONTR_ENVIRONMENT_FILE  Path to environment file. Defaults to $CONTR_CONFIG_DIR/environment
  CONTR_OPTIONS_FILE      Path to options file. Defaults to $CONTR_CONFIG_DIR/options
  CONTR_PROFILE_FILE      Path to profile file. Defaults to $CONTR_CONFIG_DIR/profile
  CONTR_STATE_DIR         State directory. Defaults to $XDG_STATE_HOME/contr or ~/.local/state/contr

Examples:
  contr alpine
  contr --pure node:alpine sh
  contr --make-config=amazon/aws-cli
  contr --plain amazon/aws-cli --version
```

## Dependencies
Contr depends on Podman and a POSIX-compliant shell with a few core utilities like `cat`, `chmod`, `grep`, `mkdir`, `tr` for operation.

The build process depends on `make`, `git` and a POSIX shell with basic core utilities like `cat`, `chmod`, `date`, `mkdir`, `sed`, `tr`.

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

## To do
* ~~Security: restore SELinux labels of bind mounted volumes. Something like running `restorecon -rF /path/to/mounted/dir` after the container is destroyed.~~ See
[danwalsh](https://opensource.com/article/18/2/selinux-labels-container-runtimes),
[distroguy](https://blog.christophersmart.com/2021/01/31/podman-volumes-and-selinux/),
[neoX](https://ahelpme.com/software/podman/change-the-location-of-container-storage-in-podman-with-selinux-enabled/),
[mutai-josphat](https://computingforgeeks.com/set-selinux-context-label-for-podman-graphroot-directory/),
[fed500](https://fedoramagazine.org/mlcube-and-podman/),
[udica](https://github.com/containers/udica),
[container-selinux-customization](https://github.com/fedora-selinux/container-selinux-customization)
* Feature: add support for OCI Hooks. This could help the previous item by running a command on a `poststop` hook. It can also improve other parts of contr, like detecting image name on a `prestart` hook (or podman's exclusive `precreate`). Check
[Podman source](https://github.com/containers/podman/tree/main/pkg/hooks),
[Podman docs](https://docs.podman.io/en/latest/markdown/podman.1.html#hooks-dir-path),
[Xin Cheng](https://faun.pub/podman-rootless-container-networking-1cb5a1973b4b)
* Feature: support using docker (and possibly also others?) in addition to podman for running containers

## License
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

See [UNLICENSE](UNLICENSE) file or http://unlicense.org/ for details.
