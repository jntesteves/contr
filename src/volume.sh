#{{{
# SPDX-License-Identifier: Unlicense
# shellcheck shell=sh disable=SC2086
public \
	NS__make_volume_noexec \
	NS__set_cwd_mode \
	NS__add_cli_filesystem

import "{ list }" from nice_things/collections/native_list.sh
#}}}
# volume.sh
# Add noexec option to a volume definition unless an exec mode is explicitly set
NS__make_volume_noexec() {
	case "$1" in
	*:*)
		NS__volume_opts=${1##*:}
		case "$NS__volume_opts" in
		*/*) printf '%s' "${1}:noexec" ;; # Slashes mean the last component is a path, there are no options
		*exec*) printf '%s' "$1" ;;       # exec/noexec already present, don't change anything
		*) printf '%s' "${1},noexec" ;;   # Add noexec to options list
		esac
		;;
	*)
		# If there are no colons we do nothing as this is an anonymous volume, which
		# does not accept options, and in our case (podman-run --rm) is transient anyway
		printf '%s' "$1"
		;;
	esac
	unset -v NS__volume_opts
}
NS__set_cwd_mode() {
	case "$1" in
	0) cwd_mode= ;;
	4) cwd_mode=ro ;;
	5) cwd_mode=ro,exec ;;
	6) cwd_mode=rw ;;
	7) cwd_mode=rw,exec ;;
	*) cwd_mode=$1 ;;
	esac
	log_debug "[NS__set_cwd_mode] cwd_mode=$cwd_mode"
}
NS__add_cli_filesystem() {
	NS__volume_option=$(NS__make_volume_noexec "${1%:*}:${1}")
	cli_filesystem_volumes=$(list $cli_filesystem_volumes "--volume=${NS__volume_option}")
	unset -v NS__volume_option
}
