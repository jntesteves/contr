#!/bin/sh
# SPDX-License-Identifier: Unlicense
VERSION='%%VERSION%%'
CMD="$(basename "$0")"
SCRIPT_NAME="$(basename "$(realpath "$0")")"
PWD=$(pwd)
config_dir="$CONTR_CONFIG_DIR"
state_dir="$CONTR_STATE_DIR"
environment_file="$CONTR_ENVIRONMENT_FILE"
options_file="$CONTR_OPTIONS_FILE"
profile_file="$CONTR_PROFILE_FILE"
is_debug="$CONTR_DEBUG"

print_help_text() {
    [ "$1" = "all" ] && podman_options="$(podman run --help | grep -E '^\s+--|^\s+-\w, --' -)"
    [ "$podman_options" ] || podman_options="  -*          Any option for the 'podman run' command. Run '$CMD --help-all' for a full list of options"

    cat <<EOF
$SCRIPT_NAME $VERSION
Run container exposing the current working directory

Usage: $CMD [OPTION...] [PODMAN OPTIONS...] IMAGE [COMMAND [ARG...]]

Options:
  --pio       Per-Image Override: per-image config files override instead of adding to global config files. Useful when the per-image config conflicts with the global config
  --plain     Do not override the image's entrypoint script
  --pure      Ignore all configuration files and the entrypoint
  --help      Print this help text and exit
  --help-all  Print this help text with all options to "podman run" included and exit

Podman options:
$podman_options

Environment variables:
  CONTR_CONFIG_DIR        Configuration directory. Defaults to \$XDG_CONFIG_HOME/$SCRIPT_NAME or ~/.config/$SCRIPT_NAME
  CONTR_STATE_DIR         State directory. Defaults to \$XDG_STATE_HOME/$SCRIPT_NAME or ~/.local/state/$SCRIPT_NAME
  CONTR_ENVIRONMENT_FILE  Path to environment file. Defaults to \$CONTR_CONFIG_DIR/environment
  CONTR_OPTIONS_FILE      Path to options file. Defaults to \$CONTR_CONFIG_DIR/options
  CONTR_PROFILE_FILE      Path to profile file. Defaults to \$CONTR_CONFIG_DIR/profile

Examples:
  $CMD alpine
  $CMD --pure node:alpine sh
  $CMD --plain amazon/aws-cli --version
EOF
    exit
}

log_error() { printf '%s\n' "$*" >&2; }
log_info() { printf '%s\n' "$*"; }
log_debug() { [ "$is_debug" ] && printf '%s\n' "DEBUG $*"; }
abort() {
    log_error "$*"
    exit 1
}

# Remove tag from a container image's name
remove_tag() {
    if [ "$(printf '%s' "$1" | grep -E -c -m 1 ':[^/]+$')" = 0 ]; then
        printf '%s' "$1"
    else
        printf '%s' "${1%:*}"
    fi
}

read_arguments() {
    log_debug "read_arguments() \$*=$*"
    case "$1" in
        --help | -h) print_help_text ;;
        --help-all) print_help_text all ;;
    esac

    for arg in "$@"; do
        case "$arg" in
            -*) ;;
            *) image="$arg" && break ;;
        esac
    done

    image_without_tag="$(remove_tag "$image")"
    log_debug "read_arguments() image='$image' image_without_tag='$image_without_tag'"
    [ "$image" ] || abort "An image must be provided. Run $CMD --help"
    [ "$HOME" = "$PWD" ] && abort "Do not use $SCRIPT_NAME in the home directory. This would expose your entire home directory inside the container, defeating the security purpose of this program."
}

check_dependencies() {
    for dep in "$@"; do
        if ! command -v "$dep" >/dev/null; then
            log_error "$dep is not installed"
            missing=1
        fi
    done

    if [ "$missing" ]; then
        abort "Aborted due to missing dependencies. Make sure all dependencies are available in the PATH"
    fi
}

set_config_files() {
    [ "$config_dir" ] || config_dir="${XDG_CONFIG_HOME:-"$HOME/.config"}/$SCRIPT_NAME"
    log_debug "set_config_files() config_dir='$config_dir'"

    [ "$state_dir" ] || state_dir="${XDG_STATE_HOME:-"$HOME/.local/state"}/$SCRIPT_NAME"
    log_debug "set_config_files() state_dir='$state_dir'"

    entrypoint_file="$state_dir/entrypoint"
    log_debug "set_config_files() entrypoint_file='$entrypoint_file'"

    [ "$environment_file" ] || environment_file="$config_dir/environment"
    log_debug "set_config_files() environment_file='$environment_file'"
    [ ! -r "$environment_file" ] && unset environment_file &&
        log_debug "set_config_files() environment_file unreadable"

    [ "$options_file" ] || options_file="$config_dir/options"
    log_debug "set_config_files() options_file='$options_file'"
    [ ! -r "$options_file" ] && unset options_file &&
        log_debug "set_config_files() options_file unreadable"

    [ "$profile_file" ] || profile_file="$config_dir/profile"
    log_debug "set_config_files() profile_file='$profile_file'"
    [ ! -r "$profile_file" ] && unset profile_file &&
        log_debug "set_config_files() profile_file unreadable"

    per_image_config_dirname="$(printf '%s' "$image_without_tag" | sed -E 's|[/:]|_|g')" # Replace / and : with _
    per_image_config_dir="$config_dir/per-image/$per_image_config_dirname"
    log_debug "set_config_files() per_image_config_dir='$per_image_config_dir'"

    per_image_environment_file="$per_image_config_dir/environment"
    log_debug "set_config_files() per_image_environment_file='$per_image_environment_file'"
    [ ! -r "$per_image_environment_file" ] && unset per_image_environment_file &&
        log_debug "set_config_files() per_image_environment_file unreadable"

    per_image_options_file="$per_image_config_dir/options"
    log_debug "set_config_files() per_image_options_file='$per_image_options_file'"
    [ ! -r "$per_image_options_file" ] && unset per_image_options_file &&
        log_debug "set_config_files() per_image_options_file unreadable"

    per_image_profile_file="$per_image_config_dir/profile"
    log_debug "set_config_files() per_image_profile_file='$per_image_profile_file'"
    [ ! -r "$per_image_profile_file" ] && unset per_image_profile_file &&
        log_debug "set_config_files() per_image_profile_file unreadable"
}

write_entrypoint_file() {
    print_entrypoint_file() {
        cat <<EOF_ENTRYPOINT_FILE
%%BUILD_ENTRYPOINT_FILE%%
EOF_ENTRYPOINT_FILE
    }

    log_debug "write_entrypoint_file() writing to file at '$1'"
    mkdir -p "$(dirname "$1")"
    print_entrypoint_file >"$1"
    chmod +x "$1"
}

main() {
    read_arguments "$@"
    check_dependencies chmod mkdir podman
    set_config_files
    user_home="$HOME"

    # Read options from command line
    while :; do
        case "$1" in
            --pio)
                log_debug "main() --pio"
                [ "$per_image_environment_file" ] && unset environment_file
                [ "$per_image_options_file" ] && unset options_file
                [ "$per_image_profile_file" ] && unset profile_file
                ;;
            --plain)
                log_debug "main() --plain"
                unset user_home
                unset entrypoint_file
                unset profile_file
                unset per_image_profile_file
                ;;
            --pure)
                log_debug "main() --pure"
                unset user_home
                unset entrypoint_file
                unset environment_file
                unset options_file
                unset profile_file
                unset per_image_environment_file
                unset per_image_options_file
                unset per_image_profile_file
                ;;
            *) break ;;
        esac
        shift # Remove option from arguments list
    done
    log_debug "main() \$*=$*"

    # Read podman options from file
    if [ "$options_file" ]; then
        while IFS= read -r line; do
            case "$line" in
                \#*) ;;                    # Ignore comments
                -*) set -- "$line" "$@" ;; # Add option to arguments list
            esac
        done <"$options_file"
        log_debug "main() \$*=$*"
    fi

    # Read per-image podman options from file
    if [ "$per_image_options_file" ]; then
        while IFS= read -r line; do
            case "$line" in
                \#*) ;;                    # Ignore comments
                -*) set -- "$line" "$@" ;; # Add option to arguments list
            esac
        done <"$per_image_options_file"
        log_debug "main() \$*=$*"
    fi

    [ "$entrypoint_file" ] && write_entrypoint_file "$entrypoint_file"

    podman run -it --rm \
        --image-volume=tmpfs \
        --tz=local \
        --group-add=keep-groups \
        --user="0:0" \
        --volume="$HOME" \
        --volume="${PWD}:${PWD}:z" \
        --workdir="$PWD" \
        --env=CONTR_DEBUG \
        --env=PS1="[📦 ${image:-"$SCRIPT_NAME"} \W]\\$ " \
        ${user_home:+"--env=HOME=$user_home"} \
        ${environment_file:+"--env-file=$environment_file"} \
        ${per_image_environment_file:+"--env-file=$per_image_environment_file"} \
        ${entrypoint_file:+"--volume=${entrypoint_file}:${entrypoint_file}:z,ro"} \
        ${entrypoint_file:+"--entrypoint=$entrypoint_file"} \
        ${entrypoint_file:+"--env=CONTR_IMAGE=$image"} \
        ${profile_file:+"--volume=${profile_file}:${profile_file}:z,ro"} \
        ${profile_file:+"--env=CONTR_PROFILE_1=${profile_file}"} \
        ${per_image_profile_file:+"--volume=${per_image_profile_file}:${per_image_profile_file}:z,ro"} \
        ${per_image_profile_file:+"--env=CONTR_PROFILE_2=${per_image_profile_file}"} \
        "$@"
}

main "$@"
