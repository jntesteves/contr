#{{{
# SPDX-License-Identifier: Unlicense
# shellcheck shell=sh
public \
	NS__get_base_name \
	NS__get_label \
	NS__pull_if_missing
#}}}
# image.sh
# get_base_name IMAGE
# Print the image's base name, with domain and tag removed
NS__get_base_name() {
	NS__base_=${1#*://}  # Remove protocol (docker://)
	case "$NS__base_" in # Remove domain
	localhost/[a-z0-9]*) NS__base_=${NS__base_#localhost/} ;;
	docker.io/library/[a-z0-9]*) NS__base_=${NS__base_#docker.io/library/} ;;
	*[.:]*/[a-z0-9]*) NS__base_=${NS__base_#*[.:]*/} ;;
	esac
	NS__base_=${NS__base_%%:*} # Remove tag
	printf '%s' "$NS__base_"
	unset -v NS__base_
}
# get_label IMAGE LABEL
# Print the value of a Label from a container image
NS__get_label() {
	podman image inspect --format "{{index .Config.Labels \"${2}\"}}" "$1"
}
NS__pull_if_missing() {
	podman image exists "$1" && :
	NS__status=$?
	if [ "$NS__status" -eq 125 ]; then
		abort "Podman error trying to access local image storage. podman-image-exists returned code 125"
	elif [ "$NS__status" -ne 0 ]; then
		podman image pull "$1" || abort "Image '${1}' does not exist and Podman failed to pull a new image"
	fi
}
