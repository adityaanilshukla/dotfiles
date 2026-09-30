# drag-mac. See PLAN.md.
#
# The venv is deliberately outside the repo: Homebrew's python3 is PEP 668
# externally managed, so `pip install --user` fails and a venv is mandatory.

VENV   := $(HOME)/.local/share/drag-mac/venv
PY     := $(VENV)/bin/python3
PIP    := $(VENV)/bin/pip
PYTEST := $(VENV)/bin/pytest

DEPS := pyobjc-framework-Cocoa pyobjc-framework-Quartz pytest

.PHONY: venv test test-unit test-gui check clean

# Idempotent: safe to re-run.
venv:
	@python3 -m venv $(VENV)
	@$(PIP) install --quiet --upgrade pip
	@$(PIP) install --quiet $(DEPS)
	@echo "venv ready: $(VENV)"

# Tier 1 only. No GUI session needed, runs anywhere.
test-unit:
	@$(PYTEST) tests/ -v -m "not gui"

# Tier 2. Spawns real windows, needs a login GUI session.
test-gui:
	@$(PYTEST) tests/ -v -m gui

test:
	@$(PYTEST) tests/ -v

# Rule 10: warnings are errors, static analysis clean.
#
# PLAN.md has named ruff as the enforcement for rules 1, 4, 6, 8 and 10 since
# it was written, and nothing ran it: `check` was pytest alone, and ruff found
# 21 findings the first time it was pointed at this directory. A rule whose
# enforcement is never invoked is a comment, so it runs here now.
#
# ruff comes from the Brewfile rather than the venv, which holds only what
# drag_mac.py imports at runtime.
check:
	@command -v ruff >/dev/null 2>&1 \
	  || { echo "ruff not installed -- brew install ruff"; exit 1; }
	@ruff check .
	@$(PYTEST) tests/ -q -W error

clean:
	@rm -rf .pytest_cache tests/__pycache__ __pycache__
	@echo "cleaned (venv left alone; use rm -rf $(VENV) to drop it)"
