#!/bin/bash
# Prints the next MAJOR.MINOR.PATCH after the highest existing vMAJOR.MINOR.PATCH tag
# (version sort, so v0.10.0 beats v0.9.0). With no such tag it starts from 0.0.0.
# Needs the tags fetched (fetch-depth: 0).
#
#   bash scripts/next_version.sh <patch|minor|major>
set -euo pipefail

bump="${1:-}"
case "$bump" in
    patch | minor | major) ;;
    *)
        echo "usage: next_version.sh <patch|minor|major>" >&2
        exit 1
        ;;
esac

# The glob also matches v1.2.3-rc1, so the exact shape is checked here.
latest="$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname \
    | awk '/^v[0-9]+\.[0-9]+\.[0-9]+$/ && !found { print substr($0, 2); found = 1 }')"
IFS=. read -r major minor patch <<< "${latest:-0.0.0}"

case "$bump" in
    major) echo "$((major + 1)).0.0" ;;
    minor) echo "$major.$((minor + 1)).0" ;;
    patch) echo "$major.$minor.$((patch + 1))" ;;
esac
