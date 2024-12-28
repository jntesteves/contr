#!/bin/sh
# SPDX-License-Identifier: Unlicense
# entrypoint - contr
#
# This file is part of contr. Do not edit this file. Use the profile
# file to setup your custom environment.
#
SCRIPT_NAME="$(basename "$(realpath "$0")")"
is_debug="${CONTR_DEBUG:+1}"

log_error() { printf '%s\n' "$*" >&2; }
log_info() { printf '%s\n' "$*"; }
log_debug() { [ "$is_debug" ] && printf 'DEBUG entrypoint %s\n' "$*"; }
abort() {
	log_error "Error on entrypoint script: $*"
	exit 1
}

[ ! -f /run/.containerenv ] && [ ! -f /.dockerenv ] &&
	abort "It seems we are not in a container. $SCRIPT_NAME is meant to run inside a container."

if [ "$CONTR_PS1" ]; then
	if [ "$PS1" != "$CONTR_PS1" ]; then
		log_debug '[ "PS1" != "CONTR_PS1" ]'
		export PS1="$CONTR_PS1"
	fi
	which_sh="$(basename "$(realpath "$(command -v sh)")")"
	if [ "$which_sh" = busybox ]; then
		log_debug 'Detected busybox, changing value of PS1'
		# Replace all occurrences of control characters 0x01 and 0x02 with textual escapes \[ and \]
		CONTR_PS1_BUSYBOX="$(printf '%s' "$CONTR_PS1" | sed -E -e 's/\x01/\\[/g' -e 's/\x02/\\]/g')"
		export PS1="$CONTR_PS1_BUSYBOX"
		export CONTR_PS1_BUSYBOX
	fi
fi
# Substitute PS1= with __PS1= in these files so our value is not overwritten
# Needed for Debian- and Ubuntu-based images
[ -w /etc/bash.bashrc ] && sed -Ei '/^\s*PS1=/s/PS1=/__&/' /etc/bash.bashrc /etc/profile /root/.bashrc /root/.profile 2>/dev/null

# Link to files in /root from HOME
if [ "$HOME" != /root ]; then
	for file in /root/.* /root/*; do
		case "$file" in
		'/root/.' | '/root/..' | '/root/.*' | '/root/*') ;;
		*)
			log_debug "ln -s $file $HOME"
			ln -s "$file" "$HOME"
			;;
		esac
	done
fi

# If HOME is in /var/home or similar, add a link to it in /home
case "$HOME" in
/*/home/*)
	mkdir -p /home
	ln -s "$HOME" "/home/$(basename "$HOME")"
	;;
esac

[ "$is_debug" ] && _dbg= || _dbg='#'
export ENV="${HOME}/.profile"

write_profile_files() {
	for p in .bashrc .cshrc .kshrc .profile .zshrc; do
		printf "\\n%s printf '~/%s sourcing %s=%s\\\\n'\\n. '%s'\\n" "$_dbg" "$p" "$1" "$2" "$2" >>"${HOME}/$p"
	done
}
[ -f "$CONTR_PROFILE_1" ] && write_profile_files CONTR_PROFILE_1 "$CONTR_PROFILE_1"
[ -f "$CONTR_PROFILE_2" ] && write_profile_files CONTR_PROFILE_2 "$CONTR_PROFILE_2"

log_debug "\$*=$*"
if command -v "$1" >/dev/null; then
	log_debug "\$1='$1' executable"
	exec "$@"
else
	log_debug "\$1='$1' non-executable"
	sh_cmd=$(command -v sh)
	bash_cmd=$(command -v bash)
	[ -x "$SHELL" ] && log_debug "SHELL=$SHELL executable"
	[ ! -x "$SHELL" ] && log_debug "SHELL=$SHELL non-executable"
	[ ! -x "$SHELL" ] && [ -x "$bash_cmd" ] && SHELL="$bash_cmd"
	[ ! -x "$SHELL" ] && [ -x /bin/bash ] && SHELL=/bin/bash
	[ ! -x "$SHELL" ] && [ -x "$sh_cmd" ] && SHELL="$sh_cmd"
	[ ! -x "$SHELL" ] && [ -x /bin/sh ] && SHELL=/bin/sh
	[ ! -x "$SHELL" ] && abort "SHELL=$SHELL not executable. Could not find an executable shell"
	log_debug "SHELL=$SHELL"
	exec $SHELL
fi
