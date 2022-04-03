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
A pre-built version is checked-in on the repository, at `target/contr`. It can be easily installed with `make install` or, without make, a simple file copy to a directory in the PATH, for example `cp target/contr ~/.local/bin/`.

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
sudo PREFIX=/usr/local make install
```

To uninstall (also with optional PREFIX):
```shell
make uninstall

sudo PREFIX=/usr/local make uninstall
```

## Contributing
Every change must pass lint and formatting validation with `make lint`. Formatting can be automatically applied with `make format`.

## License
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

See [UNLICENSE](UNLICENSE) file or http://unlicense.org/ for details.
