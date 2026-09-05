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

APP_MODES = {"if", "unless"}
DEVICE_MODES = {"device_if", "device_unless"}
VALID_MODES = APP_MODES | DEVICE_MODES

# Karabiner sorts key codes into namespaces, and the media row is spread across
# three of them: brightness and volume are consumer_key_code, mission control
# and spotlight are apple_vendor_keyboard_key_code, and do_not_disturb is
# generic_desktop. Sending one under the wrong name is not a silent no-op -
# Karabiner rejects the whole ruleset, which install.sh surfaces before writing
# anything live. A mapping names its namespace with `to_code`; the default
# covers every ordinary letter, digit and arrow.
#
# The authoritative list of which name lives where is shipped inside the app:
#   /Applications/Karabiner-Elements.app/Contents/Resources/simple_modifications.json
TO_CODE_TYPES = {
    "key_code",
    "consumer_key_code",
    "apple_vendor_keyboard_key_code",
    "apple_vendor_top_case_key_code",
    "generic_desktop",
    "pointing_button",
}


def build_conditions(spec: dict) -> dict:
    """Resolve spec.scopes into {name: conditions-list-or-None}.

    Two kinds of scope. An app scope ('if'/'unless') keys off the frontmost
    application and carries `bundle_identifiers` and/or `file_paths`. A device
    scope ('device_if'/'device_unless') keys off which keyboard the event came
    from and carries `identifiers` (vendor_id/product_id, or
    is_built_in_keyboard).

    An app scope needs at least one of the two lists, and may carry both.
    Karabiner joins every entry across BOTH lists with 'or', so an unless-scope
    listing both suppresses when either one matches. `file_paths` exists because
    a bundle identifier only exists for a real .app: a bare unix binary like
    zathura reports none at all, and no bundle_identifiers denylist can ever
    exclude it.

    A scope of null means "no conditions", i.e. the rule fires everywhere. That
    is a different thing from a scope with an empty list, which would be a typo,
    so an empty list is rejected rather than silently treated as global.
    """
    resolved: dict = {}
    for name, scope in (spec.get("scopes") or {}).items():
        if scope is None:
            resolved[name] = None
            continue

        mode = scope.get("mode", "if")
        if mode not in VALID_MODES:
            sys.exit(f"error: scope {name!r}: mode must be one of {sorted(VALID_MODES)}, got {mode!r}")

        if mode in DEVICE_MODES:
            identifiers = scope.get("identifiers") or []
            if not identifiers:
                sys.exit(f"error: scope {name!r} is a device scope but lists no identifiers.")
            resolved[name] = [{"type": mode, "identifiers": identifiers}]
            continue

        condition: dict = {"type": f"frontmost_application_{mode}"}
        for key in ("bundle_identifiers", "file_paths"):
            if scope.get(key):
                condition[key] = scope[key]

        if len(condition) == 1:
            sys.exit(
                f"error: scope {name!r} lists neither bundle_identifiers nor "
                f"file_paths. Use null for a rule that should fire everywhere."
            )

        resolved[name] = [condition]
    return resolved


def resolve_scope(group: dict, conditions_by_scope: dict, default_scope) -> list | None:
    """Resolve a group's `scope` into a conditions list, or None for everywhere.

    A group may name one scope ("browsers") or several (["glove80", "browsers"]).
    Karabiner ANDs everything in a manipulator's conditions array, so a list is
    just concatenation: this keyboard AND this app.

    `null` is only meaningful on its own. Inside a list it would be a no-op that
    reads like it widens the scope, when in fact the other entries still narrow
    it, so it is rejected rather than quietly ignored.
    """
    where = group.get("scope", default_scope)
    names = where if isinstance(where, list) else [where]

    if not names:
        sys.exit(
            f"error: group {group['description']!r} has an empty scope list. Use "
            f"null for a rule that should fire everywhere."
        )

    for name in names:
        if name not in conditions_by_scope:
            sys.exit(
                f"error: group {group['description']!r} references unknown scope "
                f"{name!r}; defined scopes are {sorted(conditions_by_scope)}"
            )

    if not isinstance(where, list):
        return conditions_by_scope[names[0]]

    conditions = []
    for name in names:
        resolved = conditions_by_scope[name]
        if resolved is None:
            sys.exit(
                f"error: group {group['description']!r} combines scope {name!r}, "
                f"which is null (everywhere), with others. Drop it from the list."
            )
        conditions.extend(resolved)
    return conditions


def build(spec: dict) -> dict:
    conditions_by_scope = build_conditions(spec)
    default_scope = spec.get("default_scope")
    prefix = spec.get("prefix", "")

    rules = []
    for group in spec["groups"]:
        conditions = resolve_scope(group, conditions_by_scope, default_scope)

        manipulators = []
        for m in group["mappings"]:
            to_code = m.get("to_code", "key_code")
            if to_code not in TO_CODE_TYPES:
                sys.exit(
                    f"error: group {group['description']!r} mapping to {m['to']!r} "
                    f"uses unknown to_code {to_code!r}; valid: {sorted(TO_CODE_TYPES)}"
                )

            from_block: dict = {"key_code": m["from"]}

            modifiers: dict = {}
            if m.get("mods"):
                modifiers["mandatory"] = m["mods"]
            if m.get("optional"):
                modifiers["optional"] = m["optional"]
            if modifiers:
                from_block["modifiers"] = modifiers

            to_event: dict = {to_code: m["to"]}
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
