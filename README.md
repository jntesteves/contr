# contr
Run container exposing the current working directory

## Usage
```
contr 0.1.0
Run container exposing the current working directory

Usage: contr [OPTION...] [PODMAN OPTIONS...] IMAGE [COMMAND [ARG...]]

Options:
  --pio       Per-Image Override: per-image config files override instead of adding to global config files. Useful when the per-image config conflicts with the global config
  --plain     Do not override the image's entrypoint script
  --pure      Ignore all configuration files and the entrypoint
  --help      Print this help text and exit
  --help-all  Print this help text with all options to "podman run" included and exit

Podman options:
  -*          Any option for the 'podman run' command. Run 'contr --help-all' for a full list of options

Environment variables:
  CONTR_CONFIG_DIR        Configuration directory. Defaults to $XDG_CONFIG_HOME/contr or ~/.config/contr
  CONTR_STATE_DIR         State directory. Defaults to $XDG_STATE_HOME/contr or ~/.local/state/contr
  CONTR_ENVIRONMENT_FILE  Path to environment file. Defaults to $CONTR_CONFIG_DIR/environment
  CONTR_OPTIONS_FILE      Path to options file. Defaults to $CONTR_CONFIG_DIR/options
  CONTR_PROFILE_FILE      Path to profile file. Defaults to $CONTR_CONFIG_DIR/profile

Examples:
  contr alpine
  contr --pure node:alpine sh
  contr --plain amazon/aws-cli --version
```

## Building and installing
To build and install into default PREFIX (`~/.local`):
```shell
make && make install
```

You can install into a different prefix by setting the PREFIX environment variable. For example:
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
