# drag-mac. See PLAN.md.
#
# The venv is deliberately outside the repo: Homebrew's python3 is PEP 668
# externally managed, so `pip install --user` fails and a venv is mandatory.

VENV   := $(HOME)/.local/share/drag-mac/venv
PY     := $(VENV)/bin/python3
PIP    := $(VENV)/bin/pip
PYTEST := $(VENV)/bin/pytest
MYPY   := $(VENV)/bin/mypy

# mypy is in the venv rather than from Homebrew, unlike ruff. It has to import
# the pyobjc modules to see them as untyped-but-present; run from outside the
# venv it reports them as missing instead, which is a different and wrong
# answer.
DEPS := pyobjc-framework-Cocoa pyobjc-framework-Quartz pytest mypy

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
# Invoked as plain `mypy`, never `mypy --strict`: the strict flag on the
# command line re-enables every strict setting and overrides the two
# exemptions pyproject.toml grants for PyObjC having no stubs.
check:
	@command -v ruff >/dev/null 2>&1 \
	  || { echo "ruff not installed -- brew install ruff"; exit 1; }
	@ruff check .
	@test -x $(MYPY) || { echo "mypy missing -- run: make venv"; exit 1; }
	@$(MYPY)
	@$(PYTEST) tests/ -q -W error

clean:
	@rm -rf .pytest_cache tests/__pycache__ __pycache__
	@echo "cleaned (venv left alone; use rm -rf $(VENV) to drop it)"
