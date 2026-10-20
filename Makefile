.PHONY: test coverage mutation lint check package run

test:
	swift test --package-path HidebarKit --disable-xctest

coverage:
	bash scripts/coverage.sh

mutation:
	bash scripts/mutation.sh

lint:
	bash scripts/adapter_lint.sh

# Release build and build/Hidebar.dmg, ad-hoc signed; see scripts/package.sh for distribution.
package:
	bash scripts/package.sh

# Debug build signed with the local identity (scripts/dev_cert.sh), then launched.
run:
	bash scripts/run.sh

# Recipe lines instead of prerequisites: `make -j check` must not run two
# swift invocations against the same .build at once.
check:
	$(MAKE) test
	$(MAKE) coverage
	$(MAKE) mutation
	$(MAKE) lint
