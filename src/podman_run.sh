#{{{
# SPDX-License-Identifier: Unlicense
# shellcheck shell=sh
public NS__podman_run
import \
	"{ to_string, list, list_from }" from nice_things/collections/native_list.sh \
	"{ substitute_characters }" from nice_things/text/substitute_characters.sh \
	"{ write_entrypoint_file }" from ./src/entrypoint.sh \
	"{ make_publish_local_only, make_volume_noexec, set_cwd_mode }" from ./src/options.sh \
	"{ add_cli_persistence_volume, create_persistence_volumes }" from ./src/persist.sh \
	"{ pull_if_missing }" from ./src/image.sh
#}}}
# podman_run.sh
NS__initialize_run_variables() {
	block_network=1
	NS__workdir=$(pwd)
	user_home="$HOME"
	entrypoint_file=
	use_entrypoint_file=1
	volume_home=1
	cwd_mode='rw,exec'
	image_persistence_volumes=
	cli_persistence_volumes=

	is_tty=
	CONTR_PS1=
	CONTR_PS1_BUSYBOX=
	if [ -t 0 ]; then
		is_tty=1
		xterm_title=
		if [ dumb != "${TERM-}" ]; then
			# shellcheck disable=SC2154
			xterm_title=$(printf '\001\033]2;\w — contr ⬢ %s\a\002' "$image")
		fi
		CONTR_PS1="$(printf '%s\n\001\033[1;36m\002\w\001\033[m\002 — contr \001\033[1;35m\002⬢ %s\001\033[m\002\n\001\033[1;90m\002❯\001\033[m\002 ' "$xterm_title" "$image")"
		# Replace all occurrences of control characters 0x01 and 0x02 with textual escapes \[ and \]
		CONTR_PS1_BUSYBOX=$(substitute_characters "$CONTR_PS1" "$(printf '\001')" '\[')
		CONTR_PS1_BUSYBOX=$(substitute_characters "$CONTR_PS1_BUSYBOX" "$(printf '\002')" '\]')
	fi

	user_id=$(id -u) || log_warn "Failed to get user id. Is the 'id' utility installed?"
	ip_unprivileged_port_start=1024
	if [ 0 = "$user_id" ]; then
		# if running as root, ignore 'ip_unprivileged_port_start'
		ip_unprivileged_port_start=
	elif command -v sysctl >/dev/null; then
		ip_unprivileged_port_start="$(sysctl net.ipv4.ip_unprivileged_port_start)" # net.ipv4.ip_unprivileged_port_start = 1024
		ip_unprivileged_port_start="${ip_unprivileged_port_start##*[!0-9]}"
	fi
	log_debug "[NS__initialize_run_variables] ip_unprivileged_port_start=$ip_unprivileged_port_start"
}

NS__podman_run() {
	check_dependencies chmod grep mkdir podman
	NS__initialize_run_variables
	pull_if_missing "$image"
	# shellcheck disable=SC2154
	create_persistence_volumes "$image" "$image_short_name"

	# Read options from command line
	while :; do
		log_debug "[NS__podman_run] option '$1'"
		case "$1" in
		-n) block_network= ;;
		--cwd-mode | --cwd-mode=) missing_opt_arg "$1" ;;
		--cwd-mode=*)
			set_cwd_mode "${1#'--cwd-mode='}"
			;;
		--no-persist) image_persistence_volumes= ;;
		--persist | --persist=) missing_opt_arg "$1" ;;
		--persist=*)
			add_cli_persistence_volume "${1#'--persist='}" "$image_short_name"
			;;
		-[04567] | -n[04567] | -[04567]n)
			opt="${1%n}"
			pad="${opt%?}"
			set_cwd_mode "${opt#"$pad"}"
			;;
		--pio)
			if [ -n "$per_image_environment_file" ]; then environment_file=; fi
			if [ -n "$per_image_options_file" ]; then options_file=; fi
			if [ -n "$per_image_profile_file" ]; then profile_file=; fi
			;;
		--plain)
			user_home=
			use_entrypoint_file=
			profile_file=
			per_image_profile_file=
			;;
		--pure)
			user_home=
			use_entrypoint_file=
			environment_file=
			options_file=
			profile_file=
			per_image_environment_file=
			per_image_options_file=
			per_image_profile_file=
			;;
		--) shift && break ;;
		*) break ;;
		esac
		shift                                # Remove option from arguments list
		image_arg_pos=$((image_arg_pos - 1)) # Decrement image position in arguments list
	done
	log_debug "[NS__podman_run] \$*=$(to_string "$@")"
	log_debug "[NS__podman_run] cli_persistence_volumes=[${cli_persistence_volumes}]"
	if [ -z "$cwd_mode" ] && [ -z "$user_home" ]; then
		volume_home=
	fi
	if [ -n "$cwd_mode" ] && [ "$HOME" = "$NS__workdir" ]; then
		abort "Do not use contr in the home directory. This is not supported, and would expose your entire home directory inside the container, defeating the security purpose of this program."
	fi

	# Read podman options from file
	if [ -n "$options_file" ]; then
		while IFS= read -r line || [ -n "$line" ]; do
			case "$line" in
			\#*) ;; # Ignore comments
			-*)
				set -- "$line" "$@"                  # Add option to arguments list
				image_arg_pos=$((image_arg_pos + 1)) # Increment image position in arguments list
				;;
			esac
		done <"$options_file"
		log_debug "[NS__podman_run] \$*=$(to_string "$@")"
	fi

	# Read per-image podman options from file
	if [ -n "$per_image_options_file" ]; then
		while IFS= read -r line || [ -n "$line" ]; do
			case "$line" in
			\#*) ;; # Ignore comments
			-*)
				set -- "$line" "$@"                  # Add option to arguments list
				image_arg_pos=$((image_arg_pos + 1)) # Increment image position in arguments list
				;;
			esac
		done <"$per_image_options_file"
		log_debug "[NS__podman_run] \$*=$(to_string "$@")"
	fi

	# Change Podman options arguments to override Podman's defaults with ours
	log_debug "[NS__podman_run] image_arg_pos=$image_arg_pos"
	argc=$#
	i=1
	while [ "$i" -le "$argc" ]; do
		opt=$1
		shifts=1
		unset -v opt_arg
		if [ "$i" -lt "$image_arg_pos" ]; then
			log_debug "${i}: $opt"
			case "$opt" in
			--net | --network | --net=* | --network=*) block_network= ;;
			-p=* | --publish=*)
				opt=$(make_publish_local_only "$opt")
				log_debug "${i}: $opt"
				;;
			-p | --publish)
				shifts=2
				opt_arg=$(make_publish_local_only "$2")
				opt_arg_pos=$((i + 1))
				log_debug "${opt_arg_pos}: $2"
				log_debug "${opt_arg_pos}: $opt_arg"
				;;
			-v=* | --volume=*)
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
		set -- "$@" "$opt" ${opt_arg+"$opt_arg"} # Add argument(s) to the end of arguments list
		shift "$shifts"                          # Remove argument(s) from the beginning of arguments list
		i=$((i + shifts))
	done
	log_debug "[NS__podman_run] \$*=$(to_string "$@")"
	[ $# = "$argc" ] || abort "Error processing arguments. We should have $argc arguments but got $# instead"

	if [ -n "$use_entrypoint_file" ]; then
		write_entrypoint_file
	fi

	# shellcheck disable=SC2086
	command podman run -i ${is_tty:+-t} --rm \
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
		${block_network:+"--network=none"} \
		${user_home:+"--env=HOME=$user_home"} \
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
		"$@"
}
