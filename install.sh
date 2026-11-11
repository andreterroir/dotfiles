#!/bin/sh
# For a local checkout; readme.md covers a fresh install.
set -eu

if ! chezmoi="$(command -v chezmoi)"; then
	bin_dir="${HOME}/.local/bin"
	chezmoi="${bin_dir}/chezmoi"
	echo "Installing chezmoi to '${chezmoi}'" >&2
	if command -v curl >/dev/null; then
		chezmoi_install_script="$(curl -fsSL get.chezmoi.io)"
	elif command -v wget >/dev/null; then
		chezmoi_install_script="$(wget -qO- get.chezmoi.io)"
	else
		echo "To install chezmoi, you must have curl or wget installed." >&2
		exit 1
	fi
	sh -c "${chezmoi_install_script}" -- -b "${bin_dir}"
	unset chezmoi_install_script bin_dir
fi

# POSIX way to get the script's directory.
script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"

"$chezmoi" init --source="${script_dir}"
# init takes no --recursive/--parent-dirs, so apply flags stay here.
echo "Running 'chezmoi apply $*'" >&2
"$chezmoi" apply --source="${script_dir}" "$@"
