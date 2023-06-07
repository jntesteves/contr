#!/usr/bin/env sh
# SPDX-License-Identifier: Unlicense
VERSION='%%VERSION%%'
CMD="$(basename "$0")"
PWD=$(pwd)
USER_ID=$(id -u)
[ -d "/run/user/$USER_ID" ] && [ -w "/run/user/$USER_ID" ] && XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$USER_ID}"
config_dir="$CONTR_CONFIG_DIR"
state_dir="$CONTR_STATE_DIR"
environment_file="$CONTR_ENVIRONMENT_FILE"
options_file="$CONTR_OPTIONS_FILE"
profile_file="$CONTR_PROFILE_FILE"
is_debug="$CONTR_DEBUG"

print_help_text() {
    podman_options=${1-"  -*                     Any option for the podman-run command. Run '$CMD --help-all' for a full list of options"}
    podman_options=${podman_options:-'  Failed to get Podman options, check if Podman is installed correctly'}

    cat <<EOF
contr $VERSION
Run container exposing the current working directory

Usage:
  $CMD [OPTION...] [PODMAN OPTIONS...] IMAGE [COMMAND [ARG...]]
  $CMD --make-config[=IMAGE]

Options:
  --make-config[=IMAGE]  Make example config files at CONTR_CONFIG_DIR. If optional IMAGE is provided, make per-image config files for that image instead of the global config files
  -n                     Allow network access
  --pio                  Per-Image Override: per-image config files override instead of adding to global config files. Useful when the per-image config conflicts with the global config
  --plain                Do not override the image's entrypoint script
  --pure                 Ignore all configuration files and custom entrypoint
  --help                 Print this help text and exit
  --help-all             Print this help text with all options to podman-run included and exit

Podman options:
$podman_options

Environment variables:
  CONTR_CONFIG_DIR        Configuration directory. Defaults to \$XDG_CONFIG_HOME/contr or ~/.config/contr
  CONTR_ENVIRONMENT_FILE  Path to environment file. Defaults to \$CONTR_CONFIG_DIR/environment
  CONTR_OPTIONS_FILE      Path to options file. Defaults to \$CONTR_CONFIG_DIR/options
  CONTR_PROFILE_FILE      Path to profile file. Defaults to \$CONTR_CONFIG_DIR/profile
  CONTR_STATE_DIR         State directory. Defaults to \$XDG_STATE_HOME/contr or ~/.local/state/contr

Examples:
  $CMD alpine
  $CMD -n node:alpine sh
  $CMD --make-config=amazon/aws-cli
  $CMD -n amazon/aws-cli aws --version
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

# Remove tag from a container image's name/URI
remove_tag() {
    if printf '%s' "$1" | grep -Eq ':[^/]+$' -; then
        printf '%s' "${1%:*}"
    else
        printf '%s' "$1"
    fi
}

# Sanitize string for use in filename. Replaces / and : with _
sanitize_for_fs() {
    printf '%s' "$*" | tr '/:' '_'
}

read_arguments() {
    log_debug "read_arguments() \$*=$*"
    block_network=1
    image=
    action='podman-run'
    podman_options="$(podman --help 2>/dev/null | grep -E '^\s+--|^\s+-\w, --' -)"
    podman_run_options="$(podman run --help 2>/dev/null | grep -E '^\s+--|^\s+-\w, --' -)"

    case "$1" in
        --make-config=*) action='make-config-per-image' && image="${1#'--make-config='}" ;;
        --make-config) action='make-config' ;;
        --help | -h) print_help_text ;;
        --help-all) print_help_text "$podman_run_options" ;;
    esac

    if [ "$action" = 'podman-run' ]; then
        # From the podman option flags, filter only those that take arguments
        print_podman_options_take_arg() {
            printf '%s\n%s' "$podman_options" "$podman_run_options" |
                grep -Ei '^\s+-\w, --\w[-a-z0-9]+ [-a-z0-9<:>[]+' - | while read -r line; do
                printf '%s\n' "${line%%,*}"
                flag=${line#*[[:space:]]}
                flag=${flag%%[[:space:]]*}
                printf '%s\n' "$flag"
            done

            printf '%s\n%s' "$podman_options" "$podman_run_options" |
                grep -Ei '^\s+--\w[-a-z0-9]+ [-a-z0-9<:>[]+' - | while read -r line; do
                printf '%s\n' "${line%%[[:space:]]*}"
            done
        }

        podman_options_take_arg="$(print_podman_options_take_arg)"

        is_podman_option() (
            if [ "$1" ]; then
                for podman_option in --net $podman_options_take_arg; do
                    [ "$podman_option" = "$1" ] && exit
                done
            fi
            exit 1
        )

        i=1
        last_flag=
        for arg in "$@"; do
            case "$arg" in
                -n | --net | --net=* | --network | --network=*) block_network= ;;
            esac
            case "$arg" in
                -*) last_flag="$arg" ;;
                *)
                    if is_podman_option "$last_flag"; then
                        last_flag=
                    else
                        image_arg_pos="$i"
                        image="$arg"
                        break
                    fi
                    ;;
            esac
            i=$((i + 1))
        done
        [ "$image" ] || abort "An image must be provided. Run $CMD --help"
    fi

    image_name="$(remove_tag "$image")"
    log_debug "read_arguments() image='$image' image_name='$image_name'"
}

check_dependencies() {
    missing=
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
    [ "$config_dir" ] || config_dir="${XDG_CONFIG_HOME:-"$HOME/.config"}/contr"
    log_debug "set_config_files() config_dir='$config_dir'"

    [ "$state_dir" ] || state_dir="${XDG_STATE_HOME:-"$HOME/.local/state"}/contr"
    log_debug "set_config_files() state_dir='$state_dir'"

    entrypoint_file="$state_dir/entrypoint"
    log_debug "set_config_files() entrypoint_file='$entrypoint_file'"

    [ "$environment_file" ] || environment_file="$config_dir/environment"
    log_debug "set_config_files() environment_file='$environment_file'"
    [ ! -r "$environment_file" ] && environment_file= &&
        log_debug "set_config_files() environment_file unreadable"

    [ "$options_file" ] || options_file="$config_dir/options"
    log_debug "set_config_files() options_file='$options_file'"
    [ ! -r "$options_file" ] && options_file= &&
        log_debug "set_config_files() options_file unreadable"

    [ "$profile_file" ] || profile_file="$config_dir/profile"
    log_debug "set_config_files() profile_file='$profile_file'"
    [ ! -r "$profile_file" ] && profile_file= &&
        log_debug "set_config_files() profile_file unreadable"

    runtime_dir="${XDG_RUNTIME_DIR:-/tmp}/contr"
    runtime_cache_dir="${runtime_dir}/cache"
    log_debug "set_config_files() runtime_cache_dir='$runtime_cache_dir'"

    per_image_config_dir=
    per_image_environment_file=
    per_image_options_file=
    per_image_profile_file=

    if [ "$image_name" ]; then
        per_image_config_dirname="$(sanitize_for_fs "$image_name")"
        per_image_config_dir="$config_dir/per-image/$per_image_config_dirname"
        log_debug "set_config_files() per_image_config_dir='$per_image_config_dir'"

        per_image_environment_file="$per_image_config_dir/environment"
        log_debug "set_config_files() per_image_environment_file='$per_image_environment_file'"
        [ ! -r "$per_image_environment_file" ] && per_image_environment_file= &&
            log_debug "set_config_files() per_image_environment_file unreadable"

        per_image_options_file="$per_image_config_dir/options"
        log_debug "set_config_files() per_image_options_file='$per_image_options_file'"
        [ ! -r "$per_image_options_file" ] && per_image_options_file= &&
            log_debug "set_config_files() per_image_options_file unreadable"

        per_image_profile_file="$per_image_config_dir/profile"
        log_debug "set_config_files() per_image_profile_file='$per_image_profile_file'"
        [ ! -r "$per_image_profile_file" ] && per_image_profile_file= &&
            log_debug "set_config_files() per_image_profile_file unreadable"
    fi
}

write_config_files() {
    target_dir="$1"

    print_environment_file() {
        cat <<EOF_ENVIRONMENT_FILE
# environment - contr
# Environment variables for containers
#
# This file is passed to the --env-file= option of the podman-run command.
# Write one variable per line. Shell features are not supported. The lines are
# read literally.
#
# To pass an environment variable from the host to a variable with the same name
# and value inside the container, write only the name of the variable on a line.
#
# Examples:
#
# aws
#AWS_ACCESS_KEY_ID=<access_key>
#AWS_SECRET_ACCESS_KEY=<secret_key>
#
# git
#GIT_DIFF_OPTS=--unified=5
#GIT_MERGE_VERBOSITY=2
#GIT_SSL_NO_VERIFY=1
#
# Forward variables from the host
#EDITOR
#LANG
#VISUAL
#
# Uncomment the following line if you don't like systemctl's auto-paging feature:
#SYSTEMD_PAGER=
#
EOF_ENVIRONMENT_FILE
    }

    print_options_file() {
        cat <<EOF_OPTIONS_FILE
# options - contr
# Options for the podman-run command
#
# Write one option per line. Shell features are not supported, not even quoting.
# The lines are read literally. Whitespace at the beginning and end of the line
# are significant, they are not trimmed.
#
# For setting environment variables, the 'environment' and 'profile' files are
# preferred over adding --env= lines here, although all three options will work.
#
# Examples:
#
# git, pijul, ssh
#--volume=${HOME}/.gitconfig:${HOME}/.gitconfig:ro
#--volume=${HOME}/.config/pijul:${HOME}/.config/pijul:ro
#--volume=${HOME}/.ssh:${HOME}/.ssh:ro
#
# aws
#--volume=aws:${HOME}/.aws
#
# User-specific executable files
#--volume=${HOME}/.local/bin:${HOME}/.local/bin:ro,exec
#
EOF_OPTIONS_FILE
    }

    print_profile_file() {
        cat <<"EOF_PROFILE_FILE"
# profile - contr
# User-specific environment for containers
#
# This file is sourced (. command) by the entrypoint shell-script inside the
# container. Use it to do any complex initialization you may require for a
# container, that can't be done with the simpler environment file.
#
# Mind that the shell executing this script may be more limited than usual, like
# busybox/ash on Alpine-based images. Therefore, try to only use POSIX-shell
# syntax and avoid any bash-isms.
#
# This file is ignored when contr is run with either the --plain or
# --pure flags
#
# Examples:
#
# User-specific executable files
#case ":${PATH}:" in
#    *:"${HOME}/.local/bin":*) ;;
#    *) export PATH="${HOME}/.local/bin:${PATH}" ;;
#esac
#
# User-specific aliases and functions
#alias grep='grep --color=auto'
#alias l.='ls -d .* --color=auto'
#alias ll='ls -l --color=auto'
#alias ls='ls --color=auto'
#
EOF_PROFILE_FILE
    }

    log_debug "write_config_files() mkdir -p \"$target_dir\""
    mkdir -p "$target_dir"

    if [ ! -f "$target_dir/environment" ]; then
        log_info "Writing config file at '$target_dir/environment'"
        print_environment_file >"$target_dir/environment"
    else
        log_info "Config file already exists at '$target_dir/environment'"
    fi

    if [ ! -f "$target_dir/options" ]; then
        log_info "Writing config file at '$target_dir/options'"
        print_options_file >"$target_dir/options"
    else
        log_info "Config file already exists at '$target_dir/options'"
    fi

    if [ ! -f "$target_dir/profile" ]; then
        log_info "Writing config file at '$target_dir/profile'"
        print_profile_file >"$target_dir/profile"
    else
        log_info "Config file already exists at '$target_dir/profile'"
    fi
}

write_entrypoint_file() {
    print_entrypoint_file() {
        cat <<"EOF_ENTRYPOINT_FILE"
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
    check_dependencies cat grep mkdir tr
    set_config_files
    user_home="$HOME"

    if [ "$action" = 'make-config' ]; then
        write_config_files "$config_dir"
        exit
    elif [ "$action" = 'make-config-per-image' ]; then
        write_config_files "$per_image_config_dir"
        exit
    fi

    # From here on we assume the default action = 'podman-run'
    check_dependencies cat chmod grep mkdir podman tr
    [ "$HOME" = "$PWD" ] && abort "Do not use contr in the home directory. This is not supported, and would expose your entire home directory inside the container, defeating the security purpose of this program."

    # Read options from command line
    while :; do
        case "$1" in
            -n) ;;
            --pio)
                log_debug "main() --pio"
                [ "$per_image_environment_file" ] && environment_file=
                [ "$per_image_options_file" ] && options_file=
                [ "$per_image_profile_file" ] && profile_file=
                ;;
            --plain)
                log_debug "main() --plain"
                user_home=
                entrypoint_file=
                profile_file=
                per_image_profile_file=
                ;;
            --pure)
                log_debug "main() --pure"
                user_home=
                entrypoint_file=
                environment_file=
                options_file=
                profile_file=
                per_image_environment_file=
                per_image_options_file=
                per_image_profile_file=
                ;;
            *) break ;;
        esac
        shift                                # Remove option from arguments list
        image_arg_pos=$((image_arg_pos - 1)) # Decrement image position in arguments list
    done
    log_debug "main() \$*=$*"

    # Read podman options from file
    if [ "$options_file" ]; then
        while IFS= read -r line; do
            case "$line" in
                \#*) ;; # Ignore comments
                -*)
                    set -- "$line" "$@"                  # Add option to arguments list
                    image_arg_pos=$((image_arg_pos + 1)) # Increment image position in arguments list
                    ;;
            esac
        done <"$options_file"
        log_debug "main() \$*=$*"
    fi

    # Read per-image podman options from file
    if [ "$per_image_options_file" ]; then
        while IFS= read -r line; do
            case "$line" in
                \#*) ;; # Ignore comments
                -*)
                    set -- "$line" "$@"                  # Add option to arguments list
                    image_arg_pos=$((image_arg_pos + 1)) # Increment image position in arguments list
                    ;;
            esac
        done <"$per_image_options_file"
        log_debug "main() \$*=$*"
    fi

    # Add noexec option to a volume definition unless an exec mode is explicitly set
    make_volume_noexec() {
        # If there are no colons we do nothing as this is an anonymous volume, which
        # does not accept options, and in our case (podman-run --rm) is transient anyway
        [ "${1##*:*}" ] && printf '%s' "$1" && exit
        volume_opts="${1##*:}"
        has_opts="${volume_opts##*/*}"
        if [ "$has_opts" ]; then
            if [ "${volume_opts##*exec*}" ]; then
                printf '%s' "${1},noexec"
            else
                printf '%s' "$1"
            fi
        else
            printf '%s' "${1}:noexec"
        fi
    }

    # Change all volume arguments to include option noexec by default, unless exec is explicitly set
    log_debug "main() image_arg_pos=$image_arg_pos"
    argc="$#"
    i=1
    while [ "$i" -le "$argc" ]; do
        opt="$1"
        shifts=1
        opt_arg=
        if [ "$i" -lt "$image_arg_pos" ]; then
            log_debug "${i}: $opt"
            case "$opt" in
                --volume=*)
                    opt=$(make_volume_noexec "$opt")
                    log_debug "${i}: $opt"
                    ;;
                -v | --volume)
                    shifts=2
                    opt_arg=$(make_volume_noexec "$2")
                    opt_arg_pos=$((i + 1))
                    log_debug "${opt_arg_pos}: $2"
                    log_debug "${opt_arg_pos}: $opt_arg"
                    ;;
            esac
        fi
        set -- "$@" "$opt" ${opt_arg:+"$opt_arg"} # Add argument(s) to the end of arguments list
        shift "$shifts"                           # Remove argument(s) from the beginning of arguments list
        i=$((i + shifts))
    done
    log_debug "main() \$*=$*"
    [ "$argc" = "$#" ] || abort "Error processing volume arguments. We should to have $argc arguments but got $# instead"

    [ "$entrypoint_file" ] && write_entrypoint_file "$entrypoint_file"
    is_tty=
    CONTR_PS1=
    if [ -t 0 ]; then
        is_tty=1
        CONTR_PS1="$(printf '\n\001\033[1;36m\002\w\001\033[m\002 inside \001\033[1;35m\002⬢ %s\001\033[m\002\n\001\033[1;90m\002❯\001\033[m\002 ' "${image:-contr}")"
    fi

    exec podman run -i ${is_tty:+-t} --rm \
        --tz=local \
        --security-opt=label=disable \
        --group-add=keep-groups \
        --user="0:0" \
        --volume="$HOME" \
        --volume="${PWD}:${PWD}:rw,exec" \
        --workdir="$PWD" \
        --env=CONTR_DEBUG \
        ${CONTR_PS1:+"--env=PS1=$CONTR_PS1" "--env=CONTR_PS1=$CONTR_PS1"} \
        ${block_network:+"--network=none"} \
        ${user_home:+"--env=HOME=$user_home"} \
        ${environment_file:+"--env-file=$environment_file"} \
        ${per_image_environment_file:+"--env-file=$per_image_environment_file"} \
        ${entrypoint_file:+"--volume=${entrypoint_file}:${entrypoint_file}:ro,exec"} \
        ${entrypoint_file:+"--entrypoint=$entrypoint_file"} \
        ${entrypoint_file:+"--env=CONTR_IMAGE=$image"} \
        ${profile_file:+"--volume=${profile_file}:${profile_file}:ro,noexec"} \
        ${profile_file:+"--env=CONTR_PROFILE_1=${profile_file}"} \
        ${per_image_profile_file:+"--volume=${per_image_profile_file}:${per_image_profile_file}:ro,noexec"} \
        ${per_image_profile_file:+"--env=CONTR_PROFILE_2=${per_image_profile_file}"} \
        "$@"
}

main "$@"
