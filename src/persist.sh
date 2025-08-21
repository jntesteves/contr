#{{{
# SPDX-License-Identifier: Unlicense
# shellcheck shell=sh disable=SC2034,SC2086
public \
	NS__add_cli_persistence_volume \
	NS__create_persistence_volumes

import \
	"{ list }" from nice_things/collections/native_list.sh \
	"{ get_label }" from ./src/image.sh
#}}}
# persist.sh
NS__get_persistence_volume_specifier_() {
	NS__mount_specifier_=$1
	case "$NS__mount_specifier_" in "~" | "~"[/:]*) NS__mount_specifier_="home${NS__mount_specifier_#"~"}" ;; esac
	case "$NS__mount_specifier_" in
	*:ro | *:ro,exec | *:ro,noexec | *:exec,ro | *:noexec,ro) return 4 ;;
	*:exec | *:noexec | *:rw,exec | *:rw,noexec | *:exec,rw | *:noexec,rw) ;;
	*:rw) NS__mount_specifier_="${NS__mount_specifier_},noexec" ;;
	*) NS__mount_specifier_="${NS__mount_specifier_}:noexec" ;;
	esac
	case "$NS__mount_specifier_" in home | home[/:]*) volume_home= ;; esac
	NS__mount_point_=$NS__mount_specifier_
	case "$NS__mount_point_" in
	home | home[/:]*) NS__mount_point_="${HOME}${NS__mount_point_#home}" ;;
	/*) ;;
	*) return 3 ;;
	esac
	NS__volume_name_=$(substitute_characters "${NS__mount_specifier_%:*}" '/' '__')
	NS__volume_name_="contr-persist.$(sanitize_for_fs "$2").$(sanitize_for_fs "$NS__volume_name_")"
	NS__volume_specifier="${NS__volume_name_}:${NS__mount_point_}"
	unset -v NS__mount_specifier_ NS__mount_point_ NS__volume_name_
}
NS__add_cli_persistence_volume() {
	NS__get_persistence_volume_specifier_ "$1" "$2" && :
	NS__status=$?
	if [ "$NS__status" -eq 3 ]; then
		abort "Error in --persist=${1} option. Persistent mounts must be absolute paths, or relative to [~ | home]"
	elif [ "$NS__status" -eq 4 ]; then
		abort "Error in --persist=${1} option. Persistent mounts can not be read-only"
	elif [ "$NS__status" -gt 0 ]; then
		abort "Unknown error in --persist=${1} option"
	fi
	cli_persistence_volumes=$(list $cli_persistence_volumes --volume="$NS__volume_specifier")
	unset -v NS__status NS__volume_specifier
}
NS__create_persistence_volumes() {
	NS__persist_label=$(get_label "$1" page.codeberg.contr.persist)
	NS__outer_ifs=$IFS
	IFS='	'
	for NS__mount_specifier in $NS__persist_label; do
		IFS=$NS__outer_ifs
		NS__get_persistence_volume_specifier_ "$NS__mount_specifier" "$2" && :
		NS__status=$?
		if [ "$NS__status" -eq 3 ]; then
			abort "Error in image's 'page.codeberg.contr.persist' label. Persistent mounts must be absolute paths, or relative to [~ | home]. Incorrect path is '${NS__mount_specifier}'"
		elif [ "$NS__status" -eq 4 ]; then
			abort "Error in image's 'page.codeberg.contr.persist' label. Persistent mounts can not be read-only. Incorrect path is '${NS__mount_specifier}'"
		elif [ "$NS__status" -gt 0 ]; then
			abort "Unknown error in image's 'page.codeberg.contr.persist' label. Incorrect path is '${NS__mount_specifier}'"
		fi
		image_persistence_volumes=$(list $image_persistence_volumes --volume="$NS__volume_specifier")
	done
	IFS=$NS__outer_ifs
	log_debug "[NS__create_persistence_volumes] image_persistence_volumes=[${image_persistence_volumes}]"
	unset -v NS__persist_label NS__outer_ifs NS__mount_specifier NS__status NS__volume_specifier
}
