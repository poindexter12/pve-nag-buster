# pve-nag-buster Makefile
# Run 'make' or 'make help' to see available commands

.PHONY: help build lint check install uninstall restore clean

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

build: ## Build install.sh from source components
	./source/build.sh

lint: ## Run ShellCheck on all scripts
	shellcheck -x source/*.sh
	shellcheck -x install.sh

check: ## Dry-run: show what would be changed (requires root)
	sudo ./install.sh --check

install: ## Install pve-nag-buster (requires root)
	sudo ./install.sh --install

uninstall: ## Remove pve-nag-buster (requires root)
	sudo ./install.sh --uninstall

restore: ## Restore proxmoxlib.js from backup (requires root)
	sudo ./install.sh --restore

clean: ## Remove build artifacts
	rm -f install.sh
