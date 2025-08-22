#!/bin/sh
# SPDX-License-Identifier: Unlicense
# shellcheck disable=SC2046,SC2086,SC2120
#{{{ strict_mode }}}
#{{{
# shellcheck disable=SC2154
import \
	./src/util.sh \
	"{ length, to_string, list, list_from }" from nice_things/collections/native_list.sh \
	"{ cat }" from nice_things/io/cat.sh \
	"{ OptionsParser, OptionsParser_optCount, OptionsParser_endOptions, OptionsParser_hasOptArg, OptionsParser_destructor }" from nice_things/cli/OptionsParser.sh \
	"{ set_config_files, write_config_files }" from ./src/config_files.sh \
	"{ get_base_name }" from ./src/image.sh \
	"{ readonly:podman_run_options, readonly:podman_options_with_arg, is_podman_option_with_arg }" from ./src/podman_options.sh \
	"{ podman_run }" from ./src/podman_run.sh
#}}}
# main.sh
usage() {
	fd=${1:+2}
	if [ -n "${2-}" ]; then log_error "$2"; fi
	NS__usage_podman_options=${3-"  -*                       Any option for the podman-run command. Run 'contr --help-all' for a full list of options"}
	NS__usage_podman_options=${NS__usage_podman_options:-"  Failed to get Podman options, check if Podman is installed correctly"}

	cat <<EOF >&"${fd:-1}"
contr {{{ PackageConfig_getProperty '' VERSION }}}
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
  --no-persist             Override "page.codeberg.contr.persist" label from image, canceling its mount points
  --persist=PATH[:exec]    Create a mount point at PATH to persist its data across invocations. PATH must be absolute or relative to [~ | home]
  --pio                    Per-Image Override: per-image config files override instead of adding to global config files. Useful when the per-image config conflicts with the global config
  --plain                  Do not override the image's entrypoint script
  --pure                   Ignore all configuration files and custom entrypoint
  --help                   Print this help text and exit
  --help-all               Print this help text with all options to podman-run included and exit

Podman options:
$NS__usage_podman_options

Environment variables:
  CONTR_CONFIG_DIR   Configuration directory. Defaults to \$XDG_CONFIG_HOME/contr or ~/.config/contr
  CONTR_RUNTIME_DIR  Runtime directory. Defaults to \$XDG_RUNTIME_DIR/contr or /run/user/\$UID/contr or /tmp/contr
  CONTR_LOG_LEVEL    Log verbosity between 0-5 where 0 is silent (default 3), also recognizes levels by name, and supports a comma separated list of options: [0|none] | [error|warn|info|debug|trace],[color|no-color]
  NO_COLOR           Same as CONTR_LOG_LEVEL=no-color (for conformance with the NO_COLOR standard)

Examples:
  contr alpine
  contr --make-config=amazon/aws-cli
  contr -n amazon/aws-cli aws --version
  contr -n -p 3000 node:alpine npm run dev -- --host 0.0.0.0
EOF
	exit ${1:+"$1"}
}

image=
image_base_name=
action=podman-run
NS__parse_option() {
	case "$2" in
	--make-config)
		action=make-config
		if [ -n "${3+1}" ]; then
			image=$3
			OptionsParser_hasOptArg "$1"
		fi
		OptionsParser_endOptions "$1"
		;;
	--help) usage ;;
	--help-all) usage '' '' "$podman_run_options" ;;
	--cwd-mode | --persist) OptionsParser_hasOptArg "$1" 1 ;;
	*)
		if is_podman_option_with_arg "$2"; then
			OptionsParser_hasOptArg "$1" 1
		fi
		;;
	esac
}

NS__set_image() {
	if [ make-config != "$action" ]; then
		shift "$(OptionsParser_optCount contr_main)" || exit
		[ -n "${1-}" ] || abort "An image must be provided. Run contr --help"
		image=$1
	fi
	image_base_name=$(get_base_name "$image")
	readonly image image_base_name
	log_debug "[NS__set_image] image='${image}' image_base_name='${image_base_name}'"
}

log_debug "[NS__main] length podman_options_with_arg=$(length $podman_options_with_arg)"
if log_is_level trace; then
	log_trace "[NS__main] podman_options_with_arg=$(to_string $podman_options_with_arg)"
fi
OptionsParser contr_main NS__parse_option "$@"
NS__set_image "$@"
OptionsParser_destructor contr_main
check_dependencies grep mkdir
set_config_files

if [ make-config = "$action" ]; then
	if [ -n "$image" ]; then
		write_config_files 1
	else
		write_config_files
	fi
else # Default action is podman-run
	podman_run "$@"
fi
