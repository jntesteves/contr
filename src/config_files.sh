#{{{
# SPDX-License-Identifier: Unlicense
# shellcheck shell=sh
public \
	NS__set_config_files \
	NS__write_config_files

import "{ cat }" from nice_things/io/cat.sh
#}}}
# config_files.sh
NS__set_config_files() {
	config_dir=${CONTR_CONFIG_DIR-}
	[ -n "$config_dir" ] || config_dir="${XDG_CONFIG_HOME:-"$HOME/.config"}/contr"
	log_debug "[NS__set_config_files] config_dir='$config_dir'"

	environment_file="$config_dir/environment"
	log_debug "[NS__set_config_files] environment_file='$environment_file'"
	if ! [ -r "$environment_file" ]; then
		environment_file=
		log_debug "[NS__set_config_files] environment_file unreadable"
	fi
	options_file="$config_dir/options"
	log_debug "[NS__set_config_files] options_file='$options_file'"
	if ! [ -r "$options_file" ]; then
		options_file=
		log_debug "[NS__set_config_files] options_file unreadable"
	fi
	profile_file="$config_dir/profile"
	log_debug "[NS__set_config_files] profile_file='$profile_file'"
	if ! [ -r "$profile_file" ]; then
		profile_file=
		log_debug "[NS__set_config_files] profile_file unreadable"
	fi

	per_image_config_dir=
	per_image_environment_file=
	per_image_options_file=
	per_image_profile_file=
	if [ -n "$image_short_name" ]; then
		per_image_config_dirname="$(sanitize_for_fs "$image_short_name")"
		per_image_config_dir="$config_dir/per-image/$per_image_config_dirname"
		log_debug "[NS__set_config_files] per_image_config_dir='$per_image_config_dir'"

		per_image_environment_file="$per_image_config_dir/environment"
		log_debug "[NS__set_config_files] per_image_environment_file='$per_image_environment_file'"
		if ! [ -r "$per_image_environment_file" ]; then
			per_image_environment_file=
			log_debug "[NS__set_config_files] per_image_environment_file unreadable"
		fi
		per_image_options_file="$per_image_config_dir/options"
		log_debug "[NS__set_config_files] per_image_options_file='$per_image_options_file'"
		if ! [ -r "$per_image_options_file" ]; then
			per_image_options_file=
			log_debug "[NS__set_config_files] per_image_options_file unreadable"
		fi
		per_image_profile_file="$per_image_config_dir/profile"
		log_debug "[NS__set_config_files] per_image_profile_file='$per_image_profile_file'"
		if ! [ -r "$per_image_profile_file" ]; then
			per_image_profile_file=
			log_debug "[NS__set_config_files] per_image_profile_file unreadable"
		fi
	fi
}
NS__write_config_files() {
	if [ "$1" ]; then
		set -- "$per_image_config_dir"
	else
		set -- "$config_dir"
	fi
	log_debug "[NS__write_config_files] mkdir -p \"$1\""
	mkdir -p "$1"

	if ! [ -f "${1}/environment" ]; then
		log_info "Writing config file at '${1}/environment'"
		NS__print_environment_file_ >"${1}/environment"
	else
		log_info "Config file already exists at '${1}/environment'"
	fi

	if ! [ -f "${1}/options" ]; then
		log_info "Writing config file at '${1}/options'"
		NS__print_options_file_ >"${1}/options"
	else
		log_info "Config file already exists at '${1}/options'"
	fi

	if ! [ -f "${1}/profile" ]; then
		log_info "Writing config file at '${1}/profile'"
		NS__print_profile_file_ >"${1}/profile"
	else
		log_info "Config file already exists at '${1}/profile'"
	fi
}
NS__print_environment_file_() {
	cat <<'EOF_ENVIRONMENT_FILE'
{{{ render ./src/environment.template.conf }}}
EOF_ENVIRONMENT_FILE
}
NS__print_options_file_() {
	cat <<EOF_OPTIONS_FILE
{{{ render ./src/options.template.conf }}}
EOF_OPTIONS_FILE
}
NS__print_profile_file_() {
	cat <<'EOF_PROFILE_FILE'
{{{ render ./src/profile.template.conf }}}
EOF_PROFILE_FILE
}
