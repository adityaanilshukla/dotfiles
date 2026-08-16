#!/usr/bin/env python3
"""Expand spec.json into a Karabiner-Elements complex_modifications ruleset.

Karabiner requires a per-manipulator `conditions` block, so app scoping has to be
repeated on every single mapping. Writing that by hand means editing dozens of
places to add one bundle id. This script keeps the source compact and generates
the verbose form.

Stdlib only. Deterministic output, so re-running produces no git diff.

Usage:  ./generate.py            # writes rules/managed.json
        ./generate.py --check    # exit 1 if the generated file is stale
"""

from __future__ import annotations

import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
SPEC = HERE / "spec.json"
DEST = HERE / "rules" / "managed.json"

VALID_MODES = {"if", "unless"}


def build_conditions(spec: dict) -> dict:
    """Resolve spec.scopes into {name: conditions-list-or-None}.

    A scope of null means "no conditions", i.e. the rule fires everywhere. That
    is a different thing from a scope with an empty app list, which would be a
    typo, so an empty list is rejected rather than silently treated as global.
    """
    resolved: dict = {}
    for name, scope in (spec.get("scopes") or {}).items():
        if scope is None:
            resolved[name] = None
            continue

        mode = scope.get("mode", "if")
        if mode not in VALID_MODES:
            sys.exit(f"error: scope {name!r}: mode must be one of {sorted(VALID_MODES)}, got {mode!r}")

        bundle_ids = scope.get("bundle_identifiers") or []
        if not bundle_ids:
            sys.exit(
                f"error: scope {name!r} lists no bundle_identifiers. Use null for a "
                f"rule that should fire everywhere."
            )

        resolved[name] = [
            {
                "type": f"frontmost_application_{mode}",
                "bundle_identifiers": bundle_ids,
            }
        ]
    return resolved


def build(spec: dict) -> dict:
    conditions_by_scope = build_conditions(spec)
    default_scope = spec.get("default_scope")
    prefix = spec.get("prefix", "")

    rules = []
    for group in spec["groups"]:
        scope_name = group.get("scope", default_scope)
        if scope_name not in conditions_by_scope:
            sys.exit(
                f"error: group {group['description']!r} references unknown scope "
                f"{scope_name!r}; defined scopes are {sorted(conditions_by_scope)}"
            )
        conditions = conditions_by_scope[scope_name]

        manipulators = []
        for m in group["mappings"]:
            from_block: dict = {"key_code": m["from"]}

            modifiers: dict = {}
            if m.get("mods"):
                modifiers["mandatory"] = m["mods"]
            if m.get("optional"):
                modifiers["optional"] = m["optional"]
            if modifiers:
                from_block["modifiers"] = modifiers

            to_event: dict = {"key_code": m["to"]}
            if m.get("to_mods"):
                to_event["modifiers"] = m["to_mods"]

            manipulator: dict = {
                "type": "basic",
                "from": from_block,
                "to": [to_event],
            }
            if conditions is not None:
                manipulator["conditions"] = conditions

            manipulators.append(manipulator)

        rules.append(
            {
                "description": prefix + group["description"],
                "manipulators": manipulators,
            }
        )

    return {"title": spec["title"], "rules": rules}


def main() -> int:
    if not SPEC.exists():
        sys.exit(f"error: {SPEC} not found")

    spec = json.loads(SPEC.read_text())
    output = json.dumps(build(spec), indent=2, ensure_ascii=False) + "\n"

    if "--check" in sys.argv:
        if not DEST.exists() or DEST.read_text() != output:
            print(f"stale: {DEST} does not match spec.json - run generate.py", file=sys.stderr)
            return 1
        print("ok: generated ruleset is current")
        return 0

    DEST.parent.mkdir(parents=True, exist_ok=True)
    DEST.write_text(output)

    n_rules = len(json.loads(output)["rules"])
    n_maps = sum(len(g["mappings"]) for g in spec["groups"])
    scopes = sorted((spec.get("scopes") or {}))

    print(f"wrote {DEST}")
    print(f"  {n_rules} rules, {n_maps} mappings, scopes: {', '.join(scopes)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
