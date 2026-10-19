"""Scores a Muter JSON report against the allowlist.

Usage: mutation_score.py REPORT.json ALLOWLIST.md THRESHOLD

Outcomes follow Muter's TestSuiteOutcome: `failed` and `runtimeError` kill a mutant,
`passed` means it survived, `buildError` is reported but not scored. Any other
outcome is an error rather than a silent pass.
"""

import json
import re
import sys

KILLED = {"failed", "runtimeError"}
SURVIVED = "passed"
NOT_SCORED = "buildError"
MUTATED_DIR_MARKER = "/HidebarKit_mutated/"
ENTRY = re.compile(r"- `(\S+\.swift:\d+:\w+)`\s+—\s+(\S.*)$")


def read_allowlist(path):
    allowed = set()
    in_entries = False
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            if line.startswith("## "):
                in_entries = line.strip() == "## Entries"
            if not in_entries or not line.startswith("- "):
                continue
            entry = ENTRY.match(line.rstrip())
            if entry is None:
                sys.exit(
                    f"mutation: malformed allowlist entry (need file:line:operatorId and reason): {line.strip()}"
                )
            allowed.add(entry.group(1))
    return allowed


def read_operators(path):
    try:
        with open(path, encoding="utf-8") as handle:
            report = json.load(handle)
        return [
            operator
            for file_report in report["fileReports"]
            for operator in file_report["appliedOperators"]
        ]
    except (OSError, ValueError, KeyError, TypeError) as error:
        sys.exit(f"mutation: cannot read Muter report {path}: {error!r}")


def mutant_key(operator):
    point = operator["mutationPoint"]
    path = point["filePath"]
    if MUTATED_DIR_MARKER not in path:
        sys.exit(f"mutation: unexpected mutant path in report: {path}")
    relative = path.split(MUTATED_DIR_MARKER, 1)[1]
    return f"{relative}:{point['position']['line']}:{point['mutationOperatorId']}"


def main(report_path, allowlist_path, threshold_arg):
    threshold = float(threshold_arg)
    allowed = read_allowlist(allowlist_path)
    operators = read_operators(report_path)
    if not operators:
        sys.exit("mutation: report contains no mutants, the gate measured nothing")

    killed = 0
    build_errors = 0
    survivors = []
    matched = set()
    for operator in operators:
        outcome = operator["testSuiteOutcome"]
        if outcome == NOT_SCORED:
            build_errors += 1
        elif outcome in KILLED:
            killed += 1
        elif outcome == SURVIVED:
            key = mutant_key(operator)
            if key in allowed:
                matched.add(key)
            else:
                survivors.append(key)
        else:
            sys.exit(f"mutation: unexpected outcome {outcome!r} in report")

    stale = sorted(allowed - matched)
    for entry in stale:
        print(f"stale allowlist entry: {entry}", file=sys.stderr)
    for survivor in survivors:
        print(f"survivor: {survivor}", file=sys.stderr)

    scored = killed + len(survivors)
    if scored == 0:
        sys.exit("mutation: no scorable mutants, the gate measured nothing")
    score = 100.0 * killed / scored
    print(
        f"HidebarCore mutation score {score:.2f}% (killed {killed}, survived {len(survivors)}, "
        f"allowlisted {len(matched)}, build errors {build_errors}, threshold {threshold:g}%)"
    )
    if stale:
        sys.exit("mutation: stale allowlist entries")
    if score < threshold:
        sys.exit("mutation: score below threshold")


if __name__ == "__main__":
    main(*sys.argv[1:4])
