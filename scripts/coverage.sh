#!/bin/bash
# Coverage gate: HidebarCore must have no missed lines and no missed functions.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root/HidebarKit"

swift test --enable-code-coverage >&2

bin_path="$(swift build --show-bin-path)"
profdata="$bin_path/codecov/default.profdata"
test_binary="$bin_path/HidebarCoreTests.xctest/Contents/MacOS/HidebarCoreTests"

report="$(xcrun llvm-cov report "$test_binary" -instr-profile="$profdata" Sources/HidebarCore)"

total="$(printf '%s\n' "$report" | /usr/bin/grep '^TOTAL ' || true)"
if [ -z "$total" ]; then
    echo "coverage: no TOTAL row for Sources/HidebarCore" >&2
    exit 1
fi

# TOTAL columns: $5 functions, $6 missed functions, $7 function coverage,
# $8 lines, $9 missed lines, $10 line coverage.
read -r functions missed_functions function_cover lines missed_lines line_cover < <(
    printf '%s\n' "$total" | /usr/bin/awk '{print $5, $6, $7, $8, $9, $10}'
)

echo "HidebarCore lines $line_cover functions $function_cover"

for value in "$functions" "$missed_functions" "$lines" "$missed_lines"; do
    case "$value" in
        '' | *[!0-9]*)
            echo "coverage: cannot parse llvm-cov TOTAL row: $total" >&2
            exit 1
            ;;
    esac
done

if [ "$functions" -eq 0 ] || [ "$lines" -eq 0 ]; then
    echo "coverage: nothing was measured in Sources/HidebarCore" >&2
    exit 1
fi

if [ "$missed_lines" -ne 0 ] || [ "$missed_functions" -ne 0 ]; then
    printf '%s\n' "$report" >&2
    echo "coverage: $missed_lines missed lines, $missed_functions missed functions (both must be 0)" >&2
    exit 1
fi
