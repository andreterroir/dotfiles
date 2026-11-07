#!/usr/bin/env bash
# vi: set ft=bash
# Earlier applies put a symlink here; a regular file belongs to the platform.
set -euo pipefail

target="$HOME/.config/amp/AGENTS.md"
if [ -L "$target" ]; then
	case "$(readlink "$target")" in
	"$HOME/.agents/AGENTS.md" | */amp-AGENTS.md)
		rm -- "$target"
		echo ">removed retired $target symlink"
		;;
	esac
fi
