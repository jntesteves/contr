#{{{
# SPDX-License-Identifier: Unlicense
# shellcheck shell=sh
public \
	readonly:NS__podman_options \
	readonly:NS__podman_run_options \
	readonly:NS__podman_options_with_arg \
	NS__is_podman_option_with_arg

import "{ to_string, list, list_from }" from nice_things/collections/native_list.sh
#}}}
# podman_options.sh
NS__podman_options=$(command podman --help 2>/dev/null | command grep -E '^\s+--|^\s+-\w, --' -) && :
NS__podman_run_options=$(command podman run --help 2>/dev/null | command grep -E '^\s+--|^\s+-\w, --' -) && :
readonly NS__podman_options NS__podman_run_options

# From the podman option flags, filter only those that take arguments
NS__print_podman_options_with_arg() {
	printf '%s\n%s' "$NS__podman_options" "$NS__podman_run_options" |
		command grep -Ei '^\s+-\w, --\w[-a-z0-9]+ [-a-z0-9<:>[]+' - | while IFS= read -r NS__line || [ -n "$NS__line" ]; do
		NS__line=${NS__line#"${NS__line%%[![:space:]]*}"} # Trim leading spaces
		printf '%s\n' "${NS__line%%,*}"
		NS__long_opt=${NS__line#*,[[:space:]]}
		NS__long_opt=${NS__long_opt%%[[:space:]]*}
		printf '%s\n' "$NS__long_opt"
	done
	printf '%s\n%s' "$NS__podman_options" "$NS__podman_run_options" |
		command grep -Ei '^\s+--\w[-a-z0-9]+ [-a-z0-9<:>[]+' - | while IFS= read -r NS__line || [ -n "$NS__line" ]; do
		NS__line=${NS__line#"${NS__line%%[![:space:]]*}"} # Trim leading spaces
		printf '%s\n' "${NS__line%%[[:space:]]*}"
	done
	unset -v NS__line NS__long_opt
}
NS__podman_options_with_arg=$(list_from "$(NS__print_podman_options_with_arg)")
readonly NS__podman_options_with_arg

NS__is_podman_option_with_arg() {
	case "$1" in "" | [!-]*) return 1 ;; esac
	for NS__podman_option in --net $NS__podman_options_with_arg; do
		if [ "$NS__podman_option" = "$1" ]; then return 0; fi
	done
	return 1
}
