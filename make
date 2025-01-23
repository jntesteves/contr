#!/bin/sh
# SPDX-License-Identifier: Unlicense
# shellcheck disable=SC2046,SC2086
. ./dot-slash-make.sh

param PREFIX="${HOME}/.local"
dist_bin=./dist/contr
shell_scripts=$(glob ./make ./*.sh ./src/*.sh ./src/*/*.sh ./src/*/*/*.sh ./test/*.sh)
case $(install -Z 2>&1) in *[Uu]nrecognized\ [Oo]ption*) selinux_flag= ;; *) selinux_flag=-Z ;; esac
build() {
	run ./nice_modules/nice_things/nice_build.sh -o ./build/entrypoint ./src/entrypoint.template.sh
	run ./nice_modules/nice_things/nice_build.sh -o ${dist_bin}
	run shfmt -w ${dist_bin}
}
lint() {
	run shellcheck "$@"
	run shfmt -d "$@"
}

while next_target; do
	case "${__target__}" in
	dist | -)
		lint ${shell_scripts}
		build
		;;
	build)
		build
		;;
	install)
		run install -D ${selinux_flag} -m 755 -t "${PREFIX}/bin" ${dist_bin}
		;;
	uninstall)
		run rm -f "${PREFIX}/bin/contr"
		;;
	lint)
		lint ${shell_scripts} ${dist_bin}
		;;
	format)
		run shfmt -w ${shell_scripts}
		;;
	dev-image)
		run podman build -f ./Containerfile.dev -t contr-dev
		;;
	# dot-slash-make: This * case must be last and should not be changed
	*) abort "No rule to make target '${__target__}'" ;;
	esac
done
