#!/usr/bin/env sh
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
    for _arg in "$@"; do
        case "$_arg" in
            --dry-run) is_dry_run=1 ;;
            --verbose | -v) is_verbose=1 ;;
            -vv) is_vv=1 && is_verbose=1 ;;
            --help | -h) print_help_text ;;
            -*) unknown_option "$_arg" ;;
            *) get_argv "$_arg" ;;
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

read_git_state() {
    git_status="$(git --no-optional-locks status --porcelain)" || abort "Failed to read git status"
    git_last_commit_info="$(git --no-optional-locks log -1 --pretty='format:(%h %cs)')" || abort "Failed to read git log"
    git_tree_is_dirty=${git_status:+1}

    log_debug "git_status=$git_status"
    log_debug "git_last_commit_info=$git_last_commit_info"
    log_debug "git_tree_is_dirty='$git_tree_is_dirty'"
}

check_dependencies() {
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

check_dependencies cat chmod date git mkdir sed tr
read_arguments "$@"
read_git_state

# Escapes text for use as replacement string in sed's 's' command
sed_replacement_escape() {
    printf '%s' "$*" | sed -E 's/[\\|/&]/\\&/g' | sed -E '$!s/$/\\n/' | tr -d '\n'
}

# Escapes text for literal use in a shell script unquoted here-doc
# shell_script_escape() {
#     printf '%s' "$*" | sed -E 's/[\\$`]/\\&/g'
# }

# Strips single quotes from text for use in a shell script single-quoted string
strip_single_quotes() {
    printf '%s' "$*" | tr -d "'"
}

# Renders a template from a file with simple string substitution
render_template() {
    _template_file="$1"
    _version="$2"
    _version="${_version}${git_tree_is_dirty:+'+dirty'} $git_last_commit_info"
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

log_info "Rendering template from $app_template_file with version=$version to file $target_file"
render_template "$app_template_file" "$version" "$entrypoint_file"

log_trace "CMD: printf '%s\n' \"${render_template_result}\" > \"$target_file\""
if [ "$is_dry_run" ]; then
    log_info "DRY-RUN CMD: mkdir -p \"$build_path\""
    log_info "DRY-RUN CMD: printf '%s' \"\$render_template_result\" > \"$target_file\""
    log_info "DRY-RUN CMD: chmod +x \"$target_file\""
else
    mkdir -p "$build_path" || abort "Failed to create build dir at $build_path"
    printf '%s\n' "$render_template_result" >"$target_file" || abort "Failed to write file $target_file"
    chmod +x "$target_file" || abort "Failed to chmod file $target_file"
fi
