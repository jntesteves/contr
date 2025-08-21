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
	NS__config_dir=${CONTR_CONFIG_DIR-}
	[ -n "$NS__config_dir" ] || NS__config_dir="${XDG_CONFIG_HOME:-"${HOME}/.config"}/contr"
	log_debug "[NS__set_config_files] NS__config_dir='${NS__config_dir}'"

	environment_file="${NS__config_dir}/environment"
	log_debug "[NS__set_config_files] environment_file='${environment_file}'"
	if ! [ -r "$environment_file" ]; then
		environment_file=
		log_debug "[NS__set_config_files] environment_file unreadable"
	fi
	options_file="${NS__config_dir}/options"
	log_debug "[NS__set_config_files] options_file='${options_file}'"
	if ! [ -r "$options_file" ]; then
		options_file=
		log_debug "[NS__set_config_files] options_file unreadable"
	fi
	profile_file="${NS__config_dir}/profile"
	log_debug "[NS__set_config_files] profile_file='${profile_file}'"
	if ! [ -r "$profile_file" ]; then
		profile_file=
		log_debug "[NS__set_config_files] profile_file unreadable"
	fi

	NS__per_image_config_dir=
	per_image_environment_file=
	per_image_options_file=
	per_image_profile_file=
	if [ -n "$image_base_name" ]; then
		NS__per_image_config_dirname=$(sanitize_for_fs "$image_base_name")
		NS__per_image_config_dir="${NS__config_dir}/per-image/${NS__per_image_config_dirname}"
		log_debug "[NS__set_config_files] NS__per_image_config_dir='${NS__per_image_config_dir}'"

		per_image_environment_file="${NS__per_image_config_dir}/environment"
		log_debug "[NS__set_config_files] per_image_environment_file='${per_image_environment_file}'"
		if ! [ -r "$per_image_environment_file" ]; then
			per_image_environment_file=
			log_debug "[NS__set_config_files] per_image_environment_file unreadable"
		fi
		per_image_options_file="${NS__per_image_config_dir}/options"
		log_debug "[NS__set_config_files] per_image_options_file='${per_image_options_file}'"
		if ! [ -r "$per_image_options_file" ]; then
			per_image_options_file=
			log_debug "[NS__set_config_files] per_image_options_file unreadable"
		fi
		per_image_profile_file="${NS__per_image_config_dir}/profile"
		log_debug "[NS__set_config_files] per_image_profile_file='${per_image_profile_file}'"
		if ! [ -r "$per_image_profile_file" ]; then
			per_image_profile_file=
			log_debug "[NS__set_config_files] per_image_profile_file unreadable"
		fi
	fi
	unset -v NS__per_image_config_dirname
}
NS__write_config_files() {
	if [ "${1-}" ]; then
		NS__config_dir_=$NS__per_image_config_dir
	else
		NS__config_dir_=$NS__config_dir
	fi
	log_debug "[NS__write_config_files] mkdir -p '${NS__config_dir_}'"
	command mkdir -p "$NS__config_dir_"

	if ! [ -f "${NS__config_dir_}/environment" ]; then
		log_info "Writing config file at '${NS__config_dir_}/environment'"
		NS__print_environment_file_ >"${NS__config_dir_}/environment"
	else
		log_info "Config file already exists at '${NS__config_dir_}/environment'"
	fi

	if ! [ -f "${NS__config_dir_}/options" ]; then
		log_info "Writing config file at '${NS__config_dir_}/options'"
		NS__print_options_file_ >"${NS__config_dir_}/options"
	else
		log_info "Config file already exists at '${NS__config_dir_}/options'"
	fi

	if ! [ -f "${NS__config_dir_}/profile" ]; then
		log_info "Writing config file at '${NS__config_dir_}/profile'"
		NS__print_profile_file_ >"${NS__config_dir_}/profile"
	else
		log_info "Config file already exists at '${NS__config_dir_}/profile'"
	fi
	unset -v NS__config_dir_
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
