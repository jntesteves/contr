#!/usr/bin/env sh
# SPDX-License-Identifier: Unlicense
version=0.5.0
app_name=contr
build_dir=dist
PREFIX=~/.local
is_debug=${BUILD_DEBUG:+1}

log_error() { printf '%s\n' "$*" >&2; }
log_info() { printf '%s\n' "$*"; }
log_debug() { [ "$is_debug" ] && printf 'DEBUG %s\n' "$*"; }
abort() {
    log_error "$*"
    exit 1
}

# Escape text for use in a shell script single-quoted string
escape_single_quotes() {
    printf '%s' "$*" | sed -E "s/'/'\\\\''/g"
}

# Wrap all arguments in single-quotes and concatenate them
quote_eval_cmd() (
    escaped_text=
    for arg in "$@"; do
        escaped_text="$escaped_text '$(escape_single_quotes "$arg")'"
    done
    printf '%s\n' "$escaped_text"
)

# Evaluate commands in a sub-shell, abort on error
run() {
    log_info "$*"
    __eval_cmd="$(quote_eval_cmd "$@")"
    log_debug "__eval_cmd=$__eval_cmd"
    (eval "$__eval_cmd") || abort 'Command failed, aborting'
}

# Evaluate commands in a sub-shell, ignore returned status code
run_() {
    log_info "$*"
    __eval_cmd="$(quote_eval_cmd "$@")"
    log_debug "__eval_cmd=$__eval_cmd"
    (eval "$__eval_cmd") || log_info 'Command failed, ignoring failure status'
}

read_arguments() {
    target=
    for arg in "$@"; do
        case "$arg" in
            PREFIX=*) PREFIX="${arg#'PREFIX='}" ;;
            *) [ "$target" ] || target="$arg" ;;
        esac
    done
}

read_arguments "$@"

case "$target" in
    "$build_dir" | '')
        run ./build.sh "$app_name" "$build_dir" "$version"
        ;;
    install)
        run install -DZ -m 755 -t "${PREFIX}/bin" "${build_dir}/$app_name"
        ;;
    uninstall)
        run rm -f "${PREFIX}/bin/$app_name"
        ;;
    lint)
        run shellcheck ./*.sh "${build_dir}/$app_name" make
        run shfmt -p -i 4 -ci -d ./*.sh "${build_dir}/$app_name" make
        ;;
    format)
        run shfmt -p -i 4 -ci -w ./*.sh make
        ;;
    develop-image)
        run podman build -f Containerfile.develop -t contr-develop
        ;;
    *) abort "No rule to make target '$target'" ;;
esac
