#{{{
# SPDX-License-Identifier: Unlicense
# shellcheck shell=sh disable=SC2086,SC2154
public NS__podman_run
import \
	"{ to_string, list, list_from }" from nice_things/collections/native_list.sh \
	"{ substitute_characters }" from nice_things/text/substitute_characters.sh \
	"{ OptionsParser, OptionsParser_optCount, OptionsParser_endOptions, OptionsParser_hasOptArg, OptionsParser_destructor }" from nice_things/cli/OptionsParser.sh \
	"{ write_entrypoint_file }" from ./src/entrypoint.sh \
	"{ make_publish_local_only, make_volume_noexec, set_cwd_mode }" from ./src/options.sh \
	"{ add_cli_persistence_volume, create_persistence_volumes }" from ./src/persist.sh \
	"{ pull_if_missing }" from ./src/image.sh
#}}}
# podman_run.sh
NS__initialize_run_variables() {
	entrypoint_file=
	volume_home=1
	cwd_mode=rw,exec
	image_persistence_volumes=
	cli_persistence_volumes=
	NS__block_network=1
	NS__workdir=$(command pwd)
	NS__user_home=$HOME
	NS__use_entrypoint_file=1
	NS__podman_arguments=

	NS__is_tty=
	CONTR_PS1=
	CONTR_PS1_BUSYBOX=
	if [ -t 0 ]; then
		NS__is_tty=1
		NS__xterm_title=
		if [ dumb != "${TERM-}" ]; then
			NS__xterm_title=$(printf '\001\033]2;\w — contr ⬢ %s\a\002' "$image")
		fi
		CONTR_PS1=$(printf '%s\n\001\033[1;36m\002\w\001\033[m\002 — contr \001\033[1;35m\002⬢ %s\001\033[m\002\n\001\033[1;90m\002❯\001\033[m\002 ' "$NS__xterm_title" "$image")
		# Replace all occurrences of control characters 0x01 and 0x02 with textual escapes \[ and \]
		CONTR_PS1_BUSYBOX=$(substitute_characters "$CONTR_PS1" "$(printf '\001')" '\[')
		CONTR_PS1_BUSYBOX=$(substitute_characters "$CONTR_PS1_BUSYBOX" "$(printf '\002')" '\]')
	fi

	NS__user_id=$(command id -u) || log_warn "Failed to get user id. Is the 'id' utility installed?"
	ip_unprivileged_port_start=1024
	if [ 0 = "$NS__user_id" ]; then
		# if running as root, ignore 'ip_unprivileged_port_start'
		ip_unprivileged_port_start=
	elif command -v sysctl >/dev/null; then
		ip_unprivileged_port_start=$(command sysctl net.ipv4.ip_unprivileged_port_start) # net.ipv4.ip_unprivileged_port_start = 1024
		ip_unprivileged_port_start=${ip_unprivileged_port_start##*[!0-9]}
	fi
	log_debug "[NS__initialize_run_variables] ip_unprivileged_port_start=$ip_unprivileged_port_start"
	unset -v NS__xterm_title NS__user_id
}

NS__parse_option() {
	case "$2" in
	-n) NS__block_network= ;;
	-[04567]) set_cwd_mode "${2#-}" ;;
	--cwd-mode) { OptionsParser_hasOptArg "$1" 1 && [ -n "${3-}" ] && set_cwd_mode "$3"; } || usage 2 "Invalid option argument ${2} '${3-}'" ;;
	--no-persist) image_persistence_volumes= ;;
	--persist) { OptionsParser_hasOptArg "$1" 1 && [ -n "${3-}" ] && add_cli_persistence_volume "$3" "$image_base_name"; } || usage 2 "Invalid option argument ${2} '${3-}'" ;;
	--pio)
		if [ -n "$per_image_environment_file" ]; then environment_file=; fi
		if [ -n "$per_image_options_file" ]; then options_file=; fi
		if [ -n "$per_image_profile_file" ]; then profile_file=; fi
		;;
	--plain)
		NS__user_home=
		NS__use_entrypoint_file=
		profile_file=
		per_image_profile_file=
		;;
	--pure)
		NS__user_home=
		NS__use_entrypoint_file=
		environment_file=
		options_file=
		profile_file=
		per_image_environment_file=
		per_image_options_file=
		per_image_profile_file=
		;;
	--net | --network)
		OptionsParser_hasOptArg "$1" 1
		NS__podman_arguments=$(list $NS__podman_arguments "$2" "$3")
		NS__block_network=
		;;
	-p | --publish)
		OptionsParser_hasOptArg "$1" 1
		NS__opt_arg=$(make_publish_local_only "$3")
		NS__podman_arguments=$(list $NS__podman_arguments "$2" "$NS__opt_arg")
		log_debug "[NS__parse_option] ${2} '${3}'"
		log_debug "[NS__parse_option] ${2} '${NS__opt_arg}'"
		;;
	-v | --volume)
		OptionsParser_hasOptArg "$1" 1
		NS__opt_arg=$(make_volume_noexec "$3")
		NS__podman_arguments=$(list $NS__podman_arguments "$2" "$NS__opt_arg")
		log_debug "[NS__parse_option] ${2} '${3}'"
		log_debug "[NS__parse_option] ${2} '${NS__opt_arg}'"
		;;
	*)
		if is_podman_option_with_arg "$2"; then
			OptionsParser_hasOptArg "$1" 1
			NS__podman_arguments=$(list $NS__podman_arguments "$2" "$3")
		else
			NS__podman_arguments=$(list $NS__podman_arguments "$2")
		fi
		;;
	esac
	unset -v NS__opt_arg
}

NS__podman_run() {
	check_dependencies chmod grep mkdir podman
	NS__initialize_run_variables
	pull_if_missing "$image"
	create_persistence_volumes "$image" "$image_base_name"

	# Read podman options from file
	if [ -n "$options_file" ]; then
		while IFS= read -r line || [ -n "$line" ]; do
			case "$line" in
			\#*) ;;                    # Ignore comments
			-*) set -- "$line" "$@" ;; # Add option to arguments list
			esac
		done <"$options_file"
		log_debug "[NS__podman_run] \$*=$(to_string "$@")"
	fi

	# Read per-image podman options from file
	if [ -n "$per_image_options_file" ]; then
		while IFS= read -r line || [ -n "$line" ]; do
			case "$line" in
			\#*) ;;                    # Ignore comments
			-*) set -- "$line" "$@" ;; # Add option to arguments list
			esac
		done <"$per_image_options_file"
		log_debug "[NS__podman_run] \$*=$(to_string "$@")"
	fi

	OptionsParser contr_run NS__parse_option "$@"
	shift "$(OptionsParser_optCount contr_run)" || exit
	OptionsParser_destructor contr_run
	log_debug "[NS__podman_run] cli_persistence_volumes=$(to_string $cli_persistence_volumes)"
	log_debug "[NS__podman_run] NS__podman_arguments=$(to_string $NS__podman_arguments)"
	log_debug "[NS__podman_run] \$*=$(to_string "$@")"

	if [ -z "$cwd_mode" ] && [ -z "$NS__user_home" ]; then
		volume_home=
	fi
	if [ -n "$cwd_mode" ] && [ "$HOME" = "$NS__workdir" ]; then
		abort "Do not use contr in the home directory. This is not supported, and would expose your entire home directory inside the container, defeating the security purpose of this program."
	fi
	if [ -n "$NS__use_entrypoint_file" ]; then
		write_entrypoint_file
	fi

	command podman run -i ${NS__is_tty:+-t} --rm \
		--tz=local \
		--security-opt=label=disable \
		--group-add=keep-groups \
		--user="0:0" \
		--pull=never \
		--env=CONTR_LOG_LEVEL \
		${volume_home:+"--volume=$HOME"} \
		${cwd_mode:+"--volume=${NS__workdir}:${NS__workdir}:$cwd_mode"} \
		${cwd_mode:+"--workdir=$NS__workdir"} \
		${CONTR_PS1:+"--env=PS1=$CONTR_PS1"} \
		${CONTR_PS1:+"--env=CONTR_PS1=$CONTR_PS1"} \
		${CONTR_PS1_BUSYBOX:+"--env=CONTR_PS1_BUSYBOX=$CONTR_PS1_BUSYBOX"} \
		${NS__block_network:+"--network=none"} \
		${NS__user_home:+"--env=HOME=$NS__user_home"} \
		${environment_file:+"--env-file=$environment_file"} \
		${per_image_environment_file:+"--env-file=$per_image_environment_file"} \
		${entrypoint_file:+"--volume=${entrypoint_file}:/run/contr/entrypoint:ro,exec"} \
		${entrypoint_file:+"--entrypoint=[\"/run/contr/entrypoint\"]"} \
		${entrypoint_file:+"--env=CONTR_IMAGE=$image"} \
		${profile_file:+"--volume=${profile_file}:/run/contr/profile1:ro,noexec"} \
		${profile_file:+"--env=CONTR_PROFILE_1=/run/contr/profile1"} \
		${per_image_profile_file:+"--volume=${per_image_profile_file}:/run/contr/profile2:ro,noexec"} \
		${per_image_profile_file:+"--env=CONTR_PROFILE_2=/run/contr/profile2"} \
		${image_persistence_volumes} \
		${cli_persistence_volumes} \
		${NS__podman_arguments} \
		"$@"
}
