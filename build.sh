#!/usr/bin/env sh
# SPDX-License-Identifier: Unlicense
CMD="$0"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
SCRIPT_NAME="$(basename "$(realpath "$0")")"
is_debug=${BUILD_DEBUG:+1}
case "$BUILD_DEBUG" in *trace*) is_trace=1 ;; esac
case "$BUILD_DEBUG" in *dry-run*) is_dry_run=1 ;; esac

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

log_error() { printf 'ERROR %s\n' "$*" >&2; }
log_warn() { printf 'WARN %s\n' "$*" >&2; }
log_info() { printf '%s\n' "$*"; }
log_debug() { [ "$is_debug" ] && printf 'DEBUG %s\n' "$*"; }
log_trace() { [ "$is_trace" ] && printf 'TRACE %s\n' "$*"; }
abort() {
    log_error "$*"
    exit 1
}
unknown_option() { abort "Unknown option $*. Run $CMD --help"; }

get_argv() {
    argc=$((argc + 1))
    case "$argc" in
        1) app_name="$1" ;;
        2) build_dir="$1" ;;
        3) version="$1" ;;
        *) abort "Too many arguments. Run $CMD --help" ;;
    esac
}

read_arguments() {
    app_name=
    build_dir=
    version=
    argc=
    for _arg in "$@"; do
        case "$_arg" in
            --dry-run) is_dry_run=1 ;;
            --verbose | -v) is_debug=1 ;;
            -vv) is_trace=1 && is_debug=1 ;;
            --help | -h) print_help_text ;;
            -*) unknown_option "$_arg" ;;
            *) get_argv "$_arg" ;;
        esac
    done

    [ "$app_name" ] || abort "Missing APP_NAME argument. Run $CMD --help"
    [ "$build_dir" ] || abort "Missing BUILD_DIR argument. Run $CMD --help"
    [ "$version" ] || abort "Missing VERSION argument. Run $CMD --help"

    case "$version" in
        *[!.0-9]*) version_is_pre_release=1 ;; # If version has any character that is not a . or a digit, it is a pre-release version
        *) version_is_pre_release= ;;
    esac
    app_template_file="${SCRIPT_DIR}/${app_name}.template.sh"
    entrypoint_file="${SCRIPT_DIR}/entrypoint.sh"
    build_path="${SCRIPT_DIR}/$build_dir"
    target_file="${build_path}/$app_name"

    log_debug "is_dry_run=$is_dry_run"
    log_debug "is_debug=$is_debug"
    log_debug "is_trace=$is_trace"
    log_debug "app_name=$app_name"
    log_debug "build_dir=$build_dir"
    log_debug "version=$version"
    log_debug "version_is_pre_release=$version_is_pre_release"
    log_debug "app_template_file=$app_template_file"
    log_debug "entrypoint_file=$entrypoint_file"
    log_debug "build_path=$build_path"
    log_debug "target_file=$target_file"
}

read_git_state() {
    git_status="$(git --no-optional-locks status --porcelain)" || abort "Failed to read git status"
    git_last_commit_info="$(git --no-optional-locks log -1 --pretty='format:(%h %cs)')" || abort "Failed to read git log"
    git_tree_is_dirty=${git_status:+1}

    log_debug "git_status=$git_status"
    log_debug "git_last_commit_info=$git_last_commit_info"
    log_debug "git_tree_is_dirty='$git_tree_is_dirty'"
}

check_dependencies() {
    missing=
    for _dep in "$@"; do
        if ! command -v "$_dep" >/dev/null; then
            log_error "$_dep is not installed"
            missing=1
        fi
    done

    if [ "$missing" ]; then
        abort "Aborted due to missing dependencies. Make sure all dependencies are available in the PATH"
    fi
}

# Escape text for literal use in a replacement string in sed's 's' command
sed_replacement_escape() {
    printf '%s' "$*" | sed -E -e 's/[\\/&]/\\&/g' -e '$!s/$/\\n/' | tr -d '\n'
}

# Strip single quotes from text for use in a shell script single-quoted string
strip_single_quotes() {
    printf '%s' "$*" | tr -d "'"
}

# Render a template from a file with simple string substitution
render_template() {
    _template_file="$1"
    _version="$2"
    _version="${_version}${git_tree_is_dirty:+'+dirty'}${version_is_pre_release:+ $git_last_commit_info}"
    _version="$(sed_replacement_escape "$(strip_single_quotes "$_version")")"
    log_debug "render_template() escaped _version=$_version"
    _entrypoint_text="$(cat "$3")"
    _entrypoint_text="$(sed_replacement_escape "$_entrypoint_text")"
    log_trace "render_template() escaped _entrypoint_text=$_entrypoint_text"
    _result="$(cat "$_template_file")"
    _result="$(printf '%s' "$_result" | sed -E "s/%%VERSION%%/$_version/g")"
    _result="$(printf '%s' "$_result" | sed -E "s/%%BUILD_ENTRYPOINT_FILE%%/$_entrypoint_text/g")"

    [ "$_result" ] || abort "render_template() _result is null"
    render_template_result="$_result"
}

main() {
    check_dependencies cat chmod date git mkdir sed tr
    read_arguments "$@"
    read_git_state

    log_info "Rendering template from $app_template_file with version=$version to file $target_file"
    render_template "$app_template_file" "$version" "$entrypoint_file"

    log_trace "CMD: printf '%s\n' \"${render_template_result}\" >\"$target_file\""
    if [ "$is_dry_run" ]; then
        log_info "DRY-RUN CMD: mkdir -p \"$build_path\""
        log_info "DRY-RUN CMD: printf '%s' \"\$render_template_result\" >\"$target_file\""
        log_info "DRY-RUN CMD: chmod +x \"$target_file\""
    else
        mkdir -p "$build_path" || abort "Failed to create build dir at $build_path"
        printf '%s\n' "$render_template_result" >"$target_file" || abort "Failed to write file $target_file"
        chmod +x "$target_file" || abort "Failed to chmod file $target_file"
    fi
}

main "$@"
