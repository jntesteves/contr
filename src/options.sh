#{{{
# SPDX-License-Identifier: Unlicense
# shellcheck shell=sh
public \
	NS__make_publish_local_only \
	NS__make_volume_noexec \
	NS__set_cwd_mode
#}}}
# options.sh
# Add 127.0.0.1 as bind address to published ports unless an address is explicitly set
# For ports 1024 and above, bind container ports to the same port number on the host if not specified
NS__make_publish_local_only() {
	NS__opt_arg="${1#'--publish='}"
	NS__opt_arg="${NS__opt_arg#'-p='}"
	NS__opt_flag= && [ "X$NS__opt_arg" != "X$1" ] && NS__opt_flag='--publish='

	print_arg() {
		if [ "${ip_unprivileged_port_start:-0}" -le "$2" ]; then
			printf '%s%s:%s:%s' "$NS__opt_flag" "$1" "${3:-"$2"}" "$2"
		else
			printf '%s%s:%s:%s' "$NS__opt_flag" "$1" "${3:-}" "$2"
		fi
	}
	case "$1" in
	*.*.*.*::*) # arg is an IP address and a container port
		NS__container_port="${NS__opt_arg##*:}"
		NS__ip_address="${NS__opt_arg%%::*}"
		print_arg "$NS__ip_address" "$NS__container_port"
		;;
	*.*.*.*:*:*) printf '%s' "$1" ;; # arg is an IP address and a pair of host:container ports, ignore
	*:*)                             # arg is a pair of host:container ports
		NS__container_port="${NS__opt_arg##*:}"
		NS__host_port="${NS__opt_arg%%:*}"
		print_arg '127.0.0.1' "$NS__container_port" "$NS__host_port"
		;;
	*) print_arg '127.0.0.1' "$NS__opt_arg" ;; # If there are no colons, arg is only a container port number
	esac
	unset -v NS__opt_arg NS__opt_flag NS__container_port NS__ip_address NS__host_port
}
# Add noexec option to a volume definition unless an exec mode is explicitly set
NS__make_volume_noexec() {
	case "$1" in
	*:*)
		NS__volume_opts="${1##*:}"
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
	*) cwd_mode="$1" ;;
	esac
	log_debug "[NS__set_cwd_mode] cwd_mode=$cwd_mode"
}
