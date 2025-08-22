#{{{
# SPDX-License-Identifier: Unlicense
# shellcheck shell=sh
import \
	"{ log_error, log_warn, log_info, log_debug, log_trace, log_is_level }" from nice_things/log/log.sh \
	"{ abort }" from nice_things/log/abort.sh \
	"{ realpath }" from nice_things/fs/realpath.sh \
	"{ substitute_characters }" from nice_things/text/substitute_characters.sh
#}}}
# util.sh
# Sanitize string for use in filename. Replaces / and : with _
sanitize_for_fs() { substitute_characters "$1" '/:' '_'; }
check_dependencies() {
	NS__missing=
	for NS__dep in "$@"; do
		if ! command -v "$NS__dep" >/dev/null; then
			log_error "$NS__dep is not installed"
			NS__missing=1
		fi
	done
	if [ -n "$NS__missing" ]; then
		abort "Aborted due to missing dependencies. Make sure all dependencies are available in the PATH"
	fi
	unset -v NS__missing NS__dep
}
is_home_dir() {
	case "${HOME%"${HOME##*[!/]}"}" in "${1%"${1##*[!/]}"}" | "$(realpath "$1" 2>/dev/null || :)") return 0 ;; esac
	return 1
}
