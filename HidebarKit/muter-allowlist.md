# Muter allowlist

Surviving HidebarCore mutants that do not fail the gate (`make mutation`).
Only equivalent mutants belong here: the change has no observable effect,
so no test can kill it. Every other mutant is killed by a test, not by an entry here.

An entry that matches no surviving mutant is stale and fails the gate.

Entry format (one line per mutant, path relative to `HidebarKit/`):

```
- `Sources/HidebarCore/<file>.swift:<line>:<operatorId>` — reason
```

Example: `Sources/HidebarCore/Clamp.swift:12:RelationalOperatorReplacement`.

## Entries

None yet.
