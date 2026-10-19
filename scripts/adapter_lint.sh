#!/bin/bash
# Adapter lint: HidebarSystem holds no logic. Each file is at most 40 lines
# and contains no if/switch/for/while.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
dir="$root/HidebarKit/Sources/HidebarSystem"
max_lines=40
failed=0

if [ ! -d "$dir" ]; then
    echo "adapter_lint: $dir does not exist" >&2
    exit 1
fi

files="$(find "$dir" -name '*.swift' | sort)"
if [ -z "$files" ]; then
    echo "adapter_lint: no .swift files in $dir, nothing was checked" >&2
    exit 1
fi

while IFS= read -r file; do
    count="$(/usr/bin/awk 'END {print NR}' "$file")"
    if [ "$count" -gt "$max_lines" ]; then
        echo "adapter_lint: $file: $count lines (max $max_lines)" >&2
        failed=1
    fi
    # grep status 1 means no match; 2 is a real error and must not pass silently.
    status=0
    matches="$(/usr/bin/grep -nE '\b(if|switch|for|while)\b' "$file")" || status=$?
    if [ "$status" -eq 0 ]; then
        printf '%s\n' "$matches" >&2
        echo "adapter_lint: $file: branching or loop keyword found" >&2
        failed=1
    elif [ "$status" -ne 1 ]; then
        echo "adapter_lint: grep failed on $file (status $status)" >&2
        exit 2
    fi
done <<< "$files"

exit "$failed"
