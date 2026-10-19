.PHONY: test coverage mutation lint check

test:
	swift test --package-path HidebarKit --disable-xctest

coverage:
	bash scripts/coverage.sh

mutation:
	bash scripts/mutation.sh

lint:
	bash scripts/adapter_lint.sh

# Recipe lines instead of prerequisites: `make -j check` must not run two
# swift invocations against the same .build at once.
check:
	$(MAKE) test
	$(MAKE) coverage
	$(MAKE) mutation
	$(MAKE) lint
