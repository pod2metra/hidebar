#!/bin/bash
# Mutation gate: Muter mutates Sources/HidebarCore; the score must reach MUTATION_THRESHOLD (default 85).
# Surviving mutants listed in HidebarKit/muter-allowlist.md count as neither killed nor survived.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
threshold="${MUTATION_THRESHOLD:-85}"
allowlist="$root/HidebarKit/muter-allowlist.md"

if ! command -v muter >/dev/null; then
    echo "mutation: muter not found (brew install muter-mutation-testing/formulae/muter)" >&2
    exit 1
fi

work="$(mktemp -d)"
cleanup() {
    rm -rf "$work" "$root/HidebarKit_mutated" "$root/HidebarKit/muter_logs"
}
trap cleanup EXIT

cd "$root/HidebarKit"
muter run --skip-update-check --format json --output "$work/report.json" >&2

/usr/bin/python3 -I "$root/scripts/mutation_score.py" "$work/report.json" "$allowlist" "$threshold"
