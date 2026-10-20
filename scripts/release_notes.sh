#!/bin/bash
# Prints release notes as a markdown list of commit subjects: everything after the closest
# earlier v* tag up to REF (default HEAD, usually the tag being released). With no earlier
# tag, every commit up to REF is listed. Needs full history and tags (fetch-depth: 0).
set -euo pipefail

ref="${1:-HEAD}"

# describe exits non-zero when no earlier v* tag exists; that is the first release, not an error.
previous="$(git describe --tags --abbrev=0 --match 'v*' "$ref^" 2>/dev/null)" || previous=""

if [ -n "$previous" ]; then
    git log --format='- %s' "$previous..$ref"
else
    git log --format='- %s' "$ref"
fi
