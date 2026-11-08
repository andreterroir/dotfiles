#!/usr/bin/env bash
# KeePassXC rewrites this file at runtime (window geometry, recent
# databases), so merge the managed keys over the file instead of
# replacing it: its keys pass through, and the repository's keys win.
set -euo pipefail

managed=$(mktemp)
current=$(mktemp)
trap 'rm -f "$managed" "$current"' EXIT
cat > "$current"
cat > "$managed" <<'EOF'
{{ include ".chezmoitemplates/keepassxc.ini" }}
EOF

awk '
    FNR == NR {
        if ($0 ~ /^\[/) {
            section = substr($0, 2, length($0) - 2)
        } else if ($0 ~ /=/) {
            id = section SUBSEP substr($0, 1, index($0, "=") - 1)
            value[id] = substr($0, index($0, "=") + 1)
            order[++n] = id
        }
        next
    }
    {
        if ($0 ~ /^\[/) {
            section = substr($0, 2, length($0) - 2)
            print
            next
        }
        if ($0 ~ /=/) {
            id = section SUBSEP substr($0, 1, index($0, "=") - 1)
            if (id in value) {
                seen[id] = 1
                print substr($0, 1, index($0, "=") - 1) "=" value[id]
                next
            }
        }
        print
    }
    END {
        section = ""
        for (i = 1; i <= n; i++) {
            id = order[i]
            if (id in seen) continue
            split(id, part, SUBSEP)
            if (part[1] != section) {
                print "[" part[1] "]"
                section = part[1]
            }
            print part[2] "=" value[id]
        }
    }
' "$managed" "$current"
