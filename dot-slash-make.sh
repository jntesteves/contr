# SPDX-License-Identifier: Unlicense
# 1.0.0-beta1
# shellcheck shell=sh
#
# This file is part of dot-slash-make https://codeberg.org/jntesteves/dot-slash-make
# Do NOT make changes to this file, your commands go in the ./make file
#
set -Cefu && IFS=$(printf '\037') || exit 111 # strict_mode

# nice_things/log/log.sh 0.1.0
case "${MAKE_LOG_LEVEL-}" in
0 | none) nice__log__log__log_is_level() { case "$1" in 0 | none) ;; *) return 1 ;; esac } ;;
5* | *trace*) nice__log__log__log_is_level() { case "$1" in 0 | none | 1 | error | 2 | warn | 3 | info | 4 | debug | 5 | trace) ;; *) return 1 ;; esac } ;;
4* | *debug*) nice__log__log__log_is_level() { case "$1" in 0 | none | 1 | error | 2 | warn | 3 | info | 4 | debug) ;; *) return 1 ;; esac } ;;
2* | *warn*) nice__log__log__log_is_level() { case "$1" in 0 | none | 1 | error | 2 | warn) ;; *) return 1 ;; esac } ;;
1* | *error*) nice__log__log__log_is_level() { case "$1" in 0 | none | 1 | error) ;; *) return 1 ;; esac } ;;
*) nice__log__log__log_is_level() { case "$1" in 0 | none | 1 | error | 2 | warn | 3 | info) ;; *) return 1 ;; esac } ;;
esac

nice__log__log__no_color=
case "${MAKE_LOG_LEVEL-}" in *no-color*) nice__log__log__no_color=1 ;; *color*) nice__log__log__no_color= ;; esac
if ! [ -t 2 ] || [ "${NO_COLOR-}" ] || [ "${TERM-}" = dumb ]; then nice__log__log__no_color=1; fi

if [ "$nice__log__log__no_color" ]; then
	nice__log__log__log_error() { :; } && if nice__log__log__log_is_level 1; then nice__log__log__log_error() { nice__log__log__outer_ifs=$IFS && IFS=' ' && { printf 'ERROR %s\n' "$*" >&2 || :; } && IFS=$nice__log__log__outer_ifs; }; fi
	nice__log__log__log_warn() { :; } && if nice__log__log__log_is_level 2; then nice__log__log__log_warn() { nice__log__log__outer_ifs=$IFS && IFS=' ' && { printf 'WARN %s\n' "$*" >&2 || :; } && IFS=$nice__log__log__outer_ifs; }; fi
	nice__log__log__log_info() { :; } && if nice__log__log__log_is_level 3; then nice__log__log__log_info() { nice__log__log__outer_ifs=$IFS && IFS=' ' && { printf '%s\n' "$*" >&2 || :; } && IFS=$nice__log__log__outer_ifs; }; fi
	nice__log__log__log_debug() { :; } && if nice__log__log__log_is_level 4; then nice__log__log__log_debug() { nice__log__log__outer_ifs=$IFS && IFS=' ' && { printf 'DEBUG %s\n' "$*" >&2 || :; } && IFS=$nice__log__log__outer_ifs; }; fi
	nice__log__log__log_trace() { :; } && if nice__log__log__log_is_level 5; then nice__log__log__log_trace() { nice__log__log__outer_ifs=$IFS && IFS=' ' && { printf 'TRACE %s\n' "$*" >&2 || :; } && IFS=$nice__log__log__outer_ifs; }; fi
else
	nice__log__log__log_error() { :; } && if nice__log__log__log_is_level 1; then nice__log__log__log_error() { nice__log__log__outer_ifs=$IFS && IFS=' ' && { printf '\001\033[1;31m\002''ERROR''\001\033[0;31m\002'' %s''\001\033[m\002''\n' "$*" >&2 || :; } && IFS=$nice__log__log__outer_ifs; }; fi
	nice__log__log__log_warn() { :; } && if nice__log__log__log_is_level 2; then nice__log__log__log_warn() { nice__log__log__outer_ifs=$IFS && IFS=' ' && { printf '\001\033[1;33m\002''WARN''\001\033[0;33m\002'' %s''\001\033[m\002''\n' "$*" >&2 || :; } && IFS=$nice__log__log__outer_ifs; }; fi
	nice__log__log__log_info() { :; } && if nice__log__log__log_is_level 3; then nice__log__log__log_info() { nice__log__log__outer_ifs=$IFS && IFS=' ' && { printf '\001\033[1;32m\002''''\001\033[m\002''%s\n' "$*" >&2 || :; } && IFS=$nice__log__log__outer_ifs; }; fi
	nice__log__log__log_debug() { :; } && if nice__log__log__log_is_level 4; then nice__log__log__log_debug() { nice__log__log__outer_ifs=$IFS && IFS=' ' && { printf '\001\033[1;36m\002''DEBUG''\001\033[m\002'' %s\n' "$*" >&2 || :; } && IFS=$nice__log__log__outer_ifs; }; fi
	nice__log__log__log_trace() { :; } && if nice__log__log__log_is_level 5; then nice__log__log__log_trace() { nice__log__log__outer_ifs=$IFS && IFS=' ' && { printf '\001\033[1;35m\002''TRACE''\001\033[m\002'' %s\n' "$*" >&2 || :; } && IFS=$nice__log__log__outer_ifs; }; fi
fi

log_error() { nice__log__log__log_error "$@"; }
log_warn() { nice__log__log__log_warn "$@"; }
log_info() { nice__log__log__log_info "$@"; }
log_debug() { nice__log__log__log_debug "$@"; }
log_trace() { nice__log__log__log_trace "$@"; }
log_is_level() { nice__log__log__log_is_level "$@"; }

# nice_things/log/abort.sh 0.1.0
nice__log__abort__abort() {
	# shellcheck disable=SC2319
	nice__log__abort__status=${2:-$?}
	[ "$nice__log__abort__status" -gt 0 ] || [ "${2-}" ] || nice__log__abort__status=1
	case "$(type nice__log__log__log_error 2>/dev/null)" in *function*) (nice__log__log__log_error "${1-}") || : ;; *) (printf '%s\n' "${1-}" >&2) || : ;; esac
	exit "$nice__log__abort__status"
}

abort() { nice__log__abort__abort "$@"; }

nice__collections__native_list__log_error() { nice__log__log__log_error "$@"; }

# nice_things/collections/native_list.sh 0.1.0
nice__collections__native_list__length() { printf '%s' $#; }
# Test if lists should have a trailing field separator in the current shell (most do, zsh differs)
# shellcheck disable=SC2086
nice__collections__native_list__list_is_terminated_=$(
	l=x, IFS=,
	if [ "$(nice__collections__native_list__length $l)" -eq 1 ]; then printf 1; fi
) || exit
readonly nice__collections__native_list__list_is_terminated_
# Test if any of the arguments is itself a list according to the current value of IFS
nice__collections__native_list__is_list() {
	while [ $# -gt 0 ]; do
		case "$1" in *["$IFS"]*) return 0 ;; esac
		shift
	done
	return 1
}
nice__collections__native_list__to_string() {
	nice__collections__native_list__outer_ifs=$IFS
	IFS=,
	printf '[%s]' "$*"
	IFS=$nice__collections__native_list__outer_ifs
}
# Turn arguments into a list of items separated by IFS
nice__collections__native_list__list() {
	if ! [ "$IFS" ]; then
		nice__collections__native_list__log_error "[nice__collections__native_list__list] Tried to create a list but IFS is null"
		return 1
	fi
	if nice__collections__native_list__is_list "$@"; then
		nice__collections__native_list__log_error "[nice__collections__native_list__list] List items cannot be lists"
		return 1
	fi
	if [ -t 1 ]; then
		nice__collections__native_list__to_string "$@"
	elif [ $# -gt 0 ]; then
		printf '%s' "$*"
		! [ "$nice__collections__native_list__list_is_terminated_" ] || printf '%s' "${IFS%"${IFS#?}"}"
	fi
}
# $(list_from text [separator]): Turn text into a list splitting at each occurrence of separator
# If separator isn't provided the default value of IFS is used (space|tab|line-feed)
nice__collections__native_list__list_from() {
	case $- in *f*) nice__collections__native_list__outer_noglob='-f' ;; *) nice__collections__native_list__outer_noglob='+f' ;; esac
	nice__collections__native_list__outer_ifs=$IFS
	set -f
	nice__collections__native_list__str=$1
	[ "$nice__collections__native_list__list_is_terminated_" ] || nice__collections__native_list__str=${1%["${2-}"]}
	IFS=${2:-' ''	''
'}
	# shellcheck disable=SC2086
	IFS=$nice__collections__native_list__outer_ifs nice__collections__native_list__list $nice__collections__native_list__str
	IFS=$nice__collections__native_list__outer_ifs
	set "$nice__collections__native_list__outer_noglob"
	unset -v nice__collections__native_list__outer_noglob nice__collections__native_list__outer_ifs nice__collections__native_list__str
}

length() { nice__collections__native_list__length "$@"; }
is_list() { nice__collections__native_list__is_list "$@"; }
to_string() { nice__collections__native_list__to_string "$@"; }
list() { nice__collections__native_list__list "$@"; }
list_from() { nice__collections__native_list__list_from "$@"; }

nice__collections__native_list_fmt__log_error() { nice__log__log__log_error "$@"; }

nice__collections__native_list_fmt__list_from() { nice__collections__native_list__list_from "$@"; }

# nice_things/collections/native_list_fmt.sh 0.1.0
# Use a printf-style pattern to format each argument, return a list separated by IFS
nice__collections__native_list_fmt__fmt() {
	nice__collections__native_list_fmt__pattern=$1
	if ! [ "$IFS" ]; then
		nice__collections__native_list_fmt__log_error "[nice__collections__native_list_fmt__fmt] Tried to create a list but IFS is null"
		return 1
	fi
	shift || {
		nice__collections__native_list_fmt__log_error "[nice__collections__native_list_fmt__fmt] A format pattern must be provided"
		return 1
	}
	if [ "$#" -gt 0 ]; then
		# shellcheck disable=SC2059
		list_from "$(printf "${nice__collections__native_list_fmt__pattern}${IFS%"${IFS#?}"}" "$@")" "${IFS%"${IFS#?}"}"
	fi
}

fmt() { nice__collections__native_list_fmt__fmt "$@"; }

nice__fs__glob__list() { nice__collections__native_list__list "$@"; }

# nice_things/fs/glob.sh 0.1.0
# glob [pattern]...
# Perform Pathname Expansion (aka globbing) on arguments
# Return a native_list of matched files, do not print the pattern if a file does not exist
nice__fs__glob__glob() {
	case $- in *f*) nice__fs__glob__outer_noglob='-f' ;; *) nice__fs__glob__outer_noglob='+f' ;; esac
	nice__fs__glob__outer_ifs=$IFS
	IFS=
	nice__fs__glob__buffer=
	set +f
	# shellcheck disable=SC2048
	for nice__fs__glob__file in $*; do
		set -f
		# shellcheck disable=SC2086
		if [ -e "$nice__fs__glob__file" ]; then nice__fs__glob__buffer=$(IFS=$nice__fs__glob__outer_ifs && nice__fs__glob__list $nice__fs__glob__buffer "$nice__fs__glob__file") || return; fi
	done
	printf '%s' "$nice__fs__glob__buffer"
	IFS=$nice__fs__glob__outer_ifs
	set "$nice__fs__glob__outer_noglob"
	unset -v nice__fs__glob__outer_noglob nice__fs__glob__outer_ifs nice__fs__glob__buffer nice__fs__glob__file
}

glob() { nice__fs__glob__glob "$@"; }

# nice_things/io/echo.sh 0.1.0
nice__io__echo__echo() (IFS=' ' && printf '%s\n' "$*")

echo() { nice__io__echo__echo "$@"; }

# nice_things/lang/is_name.sh 0.1.0
# https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap03.html#tag_03_235
# Check if each argument is a valid NAME that can be used to name a variable
nice__lang__is_name__is_name() {
	while [ $# -gt 0 ]; do
		case "$1" in '' | *[!_a-zA-Z0-9]* | [!_a-zA-Z]*) return 1 ;; esac
		shift
	done
}

nice__lang__assign__is_name() { nice__lang__is_name__is_name "$@"; }

# nice_things/lang/assign.sh 0.1.0
# Assign the output of command to variable, prevent Command Substitution truncating trailing line-feeds
nice__lang__assign__assign() {
	nice__lang__assign__is_name "${1-}" || return 113
	eval "${1}"='$( (shift && "$@"); s=$?; printf P; return $s) && :'
	eval "${1}=\${${1}%?}; return $?"
}

assign() { nice__lang__assign__assign "$@"; }

nice__lang__assign_variable__is_name() { nice__lang__is_name__is_name "$@"; }

# nice_things/lang/assign_variable.sh 0.1.0
# Use indirection to dynamically assign a variable from argument NAME=VALUE
nice__lang__assign_variable__assign_variable() {
	case "${1-}" in *?=*) ;; *) return 2 ;; esac
	nice__lang__assign_variable__is_name "${1%%=*}" || return 2
	eval "${1%%=*}"='${1#*=}'
}

assign_variable() { nice__lang__assign_variable__assign_variable "$@"; }

# main.sh

# Run command in a sub-shell, abort on error
run() {
	log_info "$@"
	("$@") || abort "${0}: [target: ${__target__}] Error ${?}"
}

# Run command in a sub-shell, ignore returned status code
_run() {
	log_info "$@"
	("$@") || log_warn "${0}: [target: ${__target__}] Error ${?} (ignored)"
}

# Check if the given name was provided as an argument in the CLI
make__main__is_in_cli_parameters_list() {
	# shellcheck disable=SC2086
	log_trace "dot-slash-make: [make__main__is_in_cli_parameters_list] var_name='${1}' make__main__cli_parameters='$(to_string $make__main__cli_parameters)'"
	for make__main__arg in $make__main__cli_parameters; do
		if [ "$1" = "$make__main__arg" ]; then return 0; fi
	done
	unset -v make__main__arg
	return 1
}

make__main__set_variable_cli_override() {
	make__main__var_name="${2%%=*}"
	if [ "$1" ] && make__main__is_in_cli_parameters_list "$make__main__var_name"; then
		log_debug "dot-slash-make: [${1}] '${make__main__var_name}' overridden by command line argument"
		return 0
	fi
	assign_variable "$2" || abort "${0}:${1:+" [$1]"} Invalid parameter name '${make__main__var_name}'"
	# shellcheck disable=SC2086
	[ "$1" ] || make__main__cli_parameters=$(list $make__main__cli_parameters "$make__main__var_name")
	eval "log_debug \"dot-slash-make: [${1:-make__main__set_variable_cli_override}] ${make__main__var_name}=\$${make__main__var_name}\""
	unset -v make__main__var_name
}

# Set variable from argument NAME=VALUE, only if it was not overridden by an argument on the CLI
param() { make__main__set_variable_cli_override param "$@"; }

# Perform Tilde Expansion and Pathname Expansion (globbing) on arguments
# Similar behavior as the wildcard function in GNU Make
wildcard() {
	make__main__wildcard_buffer=
	for make__main__wildcard_pattern in "$@"; do
		case "$make__main__wildcard_pattern" in
		"~") make__main__wildcard_pattern=$HOME ;;
		"~"/*) make__main__wildcard_pattern="${HOME}${make__main__wildcard_pattern#"~"}" ;;
		esac
		# shellcheck disable=SC2046,SC2086
		make__main__wildcard_buffer=$(list $make__main__wildcard_buffer $(glob "$make__main__wildcard_pattern")) || return
	done
	printf '%s' "$make__main__wildcard_buffer"
	unset -v make__main__wildcard_buffer make__main__wildcard_pattern
}

make__main__shift_targets_() {
	if [ $# -eq 0 ]; then return 1; fi
	__target__=$1
	shift
	make__main__targets_list_=$(list "$@")
}
# shellcheck disable=SC2086
next_target() { make__main__shift_targets_ $make__main__targets_list_; }

make__main__cli_parameters=
make__main__targets_list_=
__target__=
while [ "$#" -gt 0 ]; do
	case "$1" in
	--) ;;
	-?*) abort "${0}: Unknown option '${1}'" ;;
	[_a-zA-Z]*=*) make__main__set_variable_cli_override '' "$1" ;;
	*)
		# shellcheck disable=SC2086
		make__main__targets_list_=$(list ${make__main__targets_list_} "$1")
		;;
	esac
	shift
done
[ "$make__main__targets_list_" ] || make__main__targets_list_=-
# shellcheck disable=SC2086
log_debug "dot-slash-make: [main] make__main__targets_list_=$(to_string ${make__main__targets_list_})"
