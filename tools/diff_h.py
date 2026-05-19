#!/usr/bin/env python3
"""Diff two exported Impeller SDK headers."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any

import export_h


DEFAULT_OLD_HEADER = Path(__file__).resolve().parent / "impeller.h"


def resolve_header(path: Path) -> Path:
    if path.is_file():
        return path

    candidates = [
        path / "include" / "impeller.h",
        path / "impeller" / "include" / "impeller.h",
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate

    raise RuntimeError(f"could not find impeller.h under {path}")


def by_name(items: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    return {str(item["name"]): item for item in items}


def enum_value_key(value: dict[str, Any]) -> str:
    if value["value"] is None:
        return str(value["name"])
    return f"{value['name']} = {value['value']}"


def print_added_removed(title: str, old_items: set[str], new_items: set[str]) -> bool:
    changed = False
    added = sorted(new_items - old_items)
    removed = sorted(old_items - new_items)
    if not added and not removed:
        return False

    print(f"## {title}")
    if added:
        print()
        print("Added:")
        for item in added:
            print(f"+ {item}")
    if removed:
        print()
        print("Removed:")
        for item in removed:
            print(f"- {item}")
    print()
    return changed or bool(added or removed)


def diff_macros(old: dict[str, Any], new: dict[str, Any]) -> bool:
    old_macros = {f"{item['name']}{item['params'] or ''}": item for item in old["macros"]}
    new_macros = {f"{item['name']}{item['params'] or ''}": item for item in new["macros"]}
    changed = print_added_removed("Macros", set(old_macros), set(new_macros))

    modified = []
    for name in sorted(set(old_macros) & set(new_macros)):
        if old_macros[name]["value"] != new_macros[name]["value"]:
            modified.append((name, old_macros[name]["value"], new_macros[name]["value"]))
    if modified:
        if not changed:
            print("## Macros")
        print()
        print("Changed:")
        for name, old_value, new_value in modified:
            print(f"* {name}: {old_value} -> {new_value}")
        print()
        changed = True
    return changed


def diff_named_lists(title: str, old: list[str], new: list[str]) -> bool:
    return print_added_removed(title, set(old), set(new))


def diff_enums(old: dict[str, Any], new: dict[str, Any]) -> bool:
    old_enums = by_name(old["enums"])
    new_enums = by_name(new["enums"])
    changed = print_added_removed("Enums", set(old_enums), set(new_enums))

    for name in sorted(set(old_enums) & set(new_enums)):
        old_values = {enum_value_key(value) for value in old_enums[name]["values"]}
        new_values = {enum_value_key(value) for value in new_enums[name]["values"]}
        added = sorted(new_values - old_values)
        removed = sorted(old_values - new_values)
        if not added and not removed:
            continue

        print(f"## Enum `{name}`")
        if added:
            print()
            print("Added values:")
            for value in added:
                print(f"+ {value}")
        if removed:
            print()
            print("Removed values:")
            for value in removed:
                print(f"- {value}")
        print()
        changed = True

    return changed


def diff_structs(old: dict[str, Any], new: dict[str, Any]) -> bool:
    old_structs = by_name(old["structs"])
    new_structs = by_name(new["structs"])
    changed = print_added_removed("Structs", set(old_structs), set(new_structs))

    for name in sorted(set(old_structs) & set(new_structs)):
        old_fields = old_structs[name]["fields"]
        new_fields = new_structs[name]["fields"]
        if old_fields == new_fields:
            continue

        print(f"## Struct `{name}`")
        print()
        print("Old:")
        for field in old_fields:
            print(f"- {field}")
        print()
        print("New:")
        for field in new_fields:
            print(f"+ {field}")
        print()
        changed = True

    return changed


def diff_callbacks(old: dict[str, Any], new: dict[str, Any]) -> bool:
    old_callbacks = by_name(old["callbacks"])
    new_callbacks = by_name(new["callbacks"])
    old_signatures = {
        name: f"{item['return_type']} (*{name})({', '.join(item['params']) if item['params'] else 'void'})"
        for name, item in old_callbacks.items()
    }
    new_signatures = {
        name: f"{item['return_type']} (*{name})({', '.join(item['params']) if item['params'] else 'void'})"
        for name, item in new_callbacks.items()
    }
    changed = print_added_removed("Callbacks", set(old_callbacks), set(new_callbacks))

    modified = []
    for name in sorted(set(old_callbacks) & set(new_callbacks)):
        if old_signatures[name] != new_signatures[name]:
            modified.append((name, old_signatures[name], new_signatures[name]))
    if modified:
        if not changed:
            print("## Callbacks")
        print()
        print("Changed:")
        for name, old_signature, new_signature in modified:
            print(f"* {name}")
            print(f"  - {old_signature}")
            print(f"  + {new_signature}")
        print()
        changed = True
    return changed


def diff_functions(old: dict[str, Any], new: dict[str, Any]) -> bool:
    old_functions = by_name(old["functions"])
    new_functions = by_name(new["functions"])
    old_signatures = {name: item["signature"] for name, item in old_functions.items()}
    new_signatures = {name: item["signature"] for name, item in new_functions.items()}
    changed = print_added_removed("Functions", set(old_functions), set(new_functions))

    modified = []
    for name in sorted(set(old_functions) & set(new_functions)):
        if old_signatures[name] != new_signatures[name]:
            modified.append((name, old_signatures[name], new_signatures[name]))
    if modified:
        if not changed:
            print("## Functions")
        print()
        print("Changed signatures:")
        for name, old_signature, new_signature in modified:
            print(f"* {name}")
            print(f"  - {old_signature}")
            print(f"  + {new_signature}")
        print()
        changed = True
    return changed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--old",
        type=Path,
        default=DEFAULT_OLD_HEADER,
        help=f"Old SDK directory or impeller.h path. Defaults to {DEFAULT_OLD_HEADER}.",
    )
    parser.add_argument(
        "--new",
        type=Path,
        required=True,
        help="New SDK directory or impeller.h path.",
    )
    args = parser.parse_args()

    old_header = resolve_header(args.old)
    new_header = resolve_header(args.new)
    old = export_h.export_header(old_header)
    new = export_h.export_header(new_header)

    print("# Impeller Header Diff")
    print()
    print(f"Old: `{old_header}`")
    print(f"New: `{new_header}`")
    print()

    changed = False
    changed |= diff_macros(old, new)
    changed |= diff_named_lists("Handles", old["handles"], new["handles"])
    changed |= diff_enums(old, new)
    changed |= diff_structs(old, new)
    changed |= diff_callbacks(old, new)
    changed |= diff_functions(old, new)

    if not changed:
        print("No API surface changes found.")

    return 1 if changed else 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(2)
