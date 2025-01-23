#{{{
# SPDX-License-Identifier: Unlicense
# shellcheck shell=sh
public \
	NS__get_label \
	NS__pull_if_missing
#}}}
# image.sh
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
