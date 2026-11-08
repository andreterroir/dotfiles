#!/bin/sh
# Only for use when the repo is already cloned locally. For a fresh install
# (no repo, no chezmoi), see readme.md.
set -eu

if [ -n "${AMP_ORB:-}" ]; then
	echo "Amp orbs are not a supported target; this set-up does not run inside one." >&2
	exit 1
fi

transient=false
remaining=$#
while [ "$remaining" -gt 0 ]; do
	arg=$1
	shift
	case $arg in
		--transient) transient=true ;;
		*) set -- "$@" "$arg" ;;
	esac
	remaining=$((remaining - 1))
done

if [ "$transient" = true ]; then
	export CHEZMOI_TRANSIENT=1
fi

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

# POSIX way to get script's dir: https://stackoverflow.com/a/29834779/12156188
script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"

"$chezmoi" init --source="${script_dir}"
# init has no --recursive/--parent-dirs, so apply flags cannot move there.
echo "Running 'chezmoi apply $*'" >&2
"$chezmoi" apply --source="${script_dir}" "$@"
