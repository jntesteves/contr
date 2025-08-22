#{{{
# SPDX-License-Identifier: Unlicense
# shellcheck shell=sh
public NS__make_publish_local_only
#}}}
# network.sh
# Add 127.0.0.1 as bind address to published ports unless an address is explicitly set
# For ports 1024 and above, bind container ports to the same port number on the host if not specified
NS__make_publish_local_only() {
	NS__opt_arg=${1#--publish=}
	NS__opt_arg=${NS__opt_arg#-p=}
	NS__opt_flag= && [ "$NS__opt_arg" != "$1" ] && NS__opt_flag='--publish='

	print_arg() {
		if [ "${ip_unprivileged_port_start:-0}" -le "$2" ]; then
			printf '%s%s:%s:%s' "$NS__opt_flag" "$1" "${3:-"$2"}" "$2"
		else
			printf '%s%s:%s:%s' "$NS__opt_flag" "$1" "${3:-}" "$2"
		fi
	}
	case "$1" in
	*.*.*.*::*) # arg is an IP address and a container port
		NS__container_port=${NS__opt_arg##*:}
		NS__ip_address=${NS__opt_arg%%::*}
		print_arg "$NS__ip_address" "$NS__container_port"
		;;
	*.*.*.*:*:*) printf '%s' "$1" ;; # arg is an IP address and a pair of host:container ports, ignore
	*:*)                             # arg is a pair of host:container ports
		NS__container_port=${NS__opt_arg##*:}
		NS__host_port=${NS__opt_arg%%:*}
		print_arg '127.0.0.1' "$NS__container_port" "$NS__host_port"
		;;
	*) print_arg '127.0.0.1' "$NS__opt_arg" ;; # If there are no colons, arg is only a container port number
	esac
	unset -v NS__opt_arg NS__opt_flag NS__container_port NS__ip_address NS__host_port
}
