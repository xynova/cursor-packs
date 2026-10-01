# Append to Makefile: include hooks-install target and add hooks-install to .PHONY + help.

.PHONY: hooks-install

hooks-install: ## Install Lefthook git hooks for this clone or worktree
	@command -v lefthook >/dev/null 2>&1 || { \
		if command -v brew >/dev/null 2>&1; then brew install lefthook; \
		else go install github.com/evilmartians/lefthook@latest; fi; }
	@command -v lefthook >/dev/null 2>&1 || { echo "lefthook not on PATH; add $$(go env GOPATH)/bin"; exit 1; }
	lefthook install
