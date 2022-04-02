#!/bin/sh
# SPDX-License-Identifier: Unlicense
CMD="$0"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
SCRIPT_NAME="$(basename "$(realpath "$0")")"

print_help_text() {
    cat <<EOF
$SCRIPT_NAME - Build this project

Usage: $CMD [OPTION...] APP_NAME BUILD_DIR VERSION

Options:
    --dry-run     Only output what would be done, but don't actually do
                  anything
 -v --verbose     Output debug information (-vv very verbose)
 -h --help        Print this help text and exit
EOF
    exit
}

log_error() { printf '%s\n' "$(date -I'seconds') ERROR $*" >&2; }
log_warn() { printf '%s\n' "$(date -I'seconds') WARN $*" >&2; }
log_info() { printf '%s\n' "$(date -I'seconds') INFO $*"; }
log_debug() { [ "$is_verbose" ] && printf '%s\n' "$(date -I'seconds') DEBUG $*"; }
log_trace() { [ "$is_vv" ] && printf '%s\n' "$(date -I'seconds') TRACE $*"; }
abort() {
    log_error "$*"
    exit 1
}
unknown_option() { abort "Unknown option $*. Run $CMD --help"; }

get_argv() {
    argc=$((${argc:-0} + 1))
    case "$argc" in
        1) app_name="$1" ;;
        2) build_dir="$1" ;;
        3) version="$1" ;;
        *) abort "Too many arguments. Run $CMD --help" ;;
    esac
}

read_arguments() {
    for arg in "$@"; do
        case "$arg" in
            --dry-run) is_dry_run=1 ;;
            --verbose | -v) is_verbose=1 ;;
            -vv) is_vv=1 && is_verbose=1 ;;
            --help | -h) print_help_text ;;
            -*) unknown_option "$arg" ;;
            *) get_argv "$arg" ;;
        esac
    done

    [ "$app_name" ] || abort "Missing APP_NAME argument. Run $CMD --help"
    [ "$build_dir" ] || abort "Missing BUILD_DIR argument. Run $CMD --help"
    [ "$version" ] || abort "Missing VERSION argument. Run $CMD --help"

    app_template_file="${SCRIPT_DIR}/${app_name}.template.sh"
    entrypoint_file="${SCRIPT_DIR}/entrypoint.sh"
    build_path="${SCRIPT_DIR}/$build_dir"
    target_file="${build_path}/$app_name"

    log_debug "is_dry_run=$is_dry_run"
    log_debug "is_verbose=$is_verbose"
    log_debug "is_vv=$is_vv"
    log_debug "app_name=$app_name"
    log_debug "build_dir=$build_dir"
    log_debug "version=$version"
    log_debug "app_template_file=$app_template_file"
    log_debug "entrypoint_file=$entrypoint_file"
    log_debug "build_path=$build_path"
    log_debug "target_file=$target_file"
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

check_dependencies cat chmod date mkdir sed tr
read_arguments "$@"

# Escapes text for use as replacement string in sed's 's' command
sed_replacement_escape() {
    printf '%s' "$(printf '%s' "$*" | sed -E 's/[\\|/&]/\\&/g' | sed -E '$!s/$/\\n/' | tr -d '\n')"
}

# Escapes text for use in a shell script here-doc block
shell_script_escape() {
    printf '%s' "$(printf '%s' "$*" | sed -E 's/[\\$]/\\&/g')"
}

# Renders a template from a file with simple string substitution
render_template() {
    rt_template_file="$1"
    rt_version="$(sed_replacement_escape "$(shell_script_escape "$2")")"
    log_debug "render_template() escaped rt_version=$rt_version"
    rt_entrypoint_text="$(cat "$3")"
    rt_entrypoint_text="$(sed_replacement_escape "$(shell_script_escape "$rt_entrypoint_text")")"
    log_trace "render_template() escaped rt_entrypoint_text=$rt_entrypoint_text"
    result="$(cat "$rt_template_file")"
    result="$(printf '%s' "$result" | sed -E "s/%%VERSION%%/$rt_version/g")"
    result="$(printf '%s' "$result" | sed -E "s/%%BUILD_ENTRYPOINT_FILE%%/$rt_entrypoint_text/g")"

    [ "$result" ] || abort "render_template() result is null"
    render_template_result="$result"
}

log_info "Rendering template from $app_template_file with version=$version to file $target_file"
render_template "$app_template_file" "$version" "$entrypoint_file"

log_trace "CMD: printf '%s\n' \"${render_template_result}\" > \"$target_file\""
if [ "$is_dry_run" ]; then
    log_info "DRY-RUN CMD: printf '%s' \"\$render_template_result\" > \"$target_file\""
else
    mkdir -p "$build_path" || abort "Failed to create build dir at $build_path"
    printf '%s\n' "$render_template_result" >"$target_file" || abort "Failed to write file $target_file"
    chmod +x "$target_file"
fi
