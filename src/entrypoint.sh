#{{{
# SPDX-License-Identifier: Unlicense
# shellcheck shell=sh
public NS__write_entrypoint_file

import \
	"{ cat }" from nice_things/io/cat.sh \
	"{ create_runtime_file }" from nice_things/storage/create_runtime_file.sh \
	"{ setup_runtime_dir }" from nice_things/storage/setup_runtime_dir.sh
#}}}
# entrypoint.sh
NS__write_entrypoint_file() {
	setup_runtime_dir contr
	entrypoint_file=$(create_runtime_file entrypoint/entrypoint) || abort "Failed to write entrypoint file"
	log_debug "[NS__write_entrypoint_file] writing to file at '${entrypoint_file}'"
	NS__print_entrypoint_file_ >|"$entrypoint_file" || abort "Failed to write entrypoint file"
	command chmod +x "$entrypoint_file" || abort "Failed to set execute bit on entrypoint file"
}
NS__print_entrypoint_file_() {
	cat <<"EOF_ENTRYPOINT_FILE"
{{{ cat ./build/entrypoint }}}
EOF_ENTRYPOINT_FILE
}
