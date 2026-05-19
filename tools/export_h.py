#!/usr/bin/env python3
"""Export the public symbols from Impeller's standalone SDK header."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


DEFAULT_HEADER = Path("vendor/impeller/include/impeller.h")
ATTRIBUTE_MACROS = {
    "IMPELLER_EXPORT",
    "IMPELLER_NODISCARD",
    "IMPELLER_NULLABLE",
    "IMPELLER_NONNULL",
}


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"//.*", "", text)
    return text


def normalize_space(text: str) -> str:
    return " ".join(text.split())


def clean_decl(text: str) -> str:
    text = strip_comments(text)
    text = normalize_space(text)
    for macro in ATTRIBUTE_MACROS:
        text = re.sub(rf"\b{macro}\b", "", text)
    return normalize_space(text)


def logical_lines(text: str) -> list[str]:
    lines: list[str] = []
    current = ""
    for line in text.splitlines():
        stripped = line.rstrip()
        if stripped.endswith("\\"):
            current += stripped[:-1] + " "
            continue
        lines.append(current + stripped)
        current = ""
    if current:
        lines.append(current)
    return lines


def split_comma_list(text: str) -> list[str]:
    items: list[str] = []
    current: list[str] = []
    depth = 0
    for char in text:
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        elif char == "," and depth == 0:
            item = normalize_space("".join(current))
            if item:
                items.append(item)
            current = []
            continue
        current.append(char)

    item = normalize_space("".join(current))
    if item:
        items.append(item)
    return items


def parse_handles(text: str) -> list[str]:
    return re.findall(r"IMPELLER_DEFINE_HANDLE\((Impeller[A-Za-z0-9_]+)\)", text)


def parse_macros(text: str) -> list[dict[str, Any]]:
    macros: list[dict[str, Any]] = []
    for line in logical_lines(strip_comments(text)):
        match = re.match(
            r"\s*#define\s+(?P<name>IMPELLER_[A-Za-z0-9_]+)(?P<params>\([^)]*\))?\s*(?P<value>.*)",
            line,
        )
        if not match:
            continue
        name = match.group("name")
        if name.startswith("IMPELLER_EXPORT") or name in {
            "IMPELLER_EXTERN_C",
            "IMPELLER_EXTERN_C_BEGIN",
            "IMPELLER_EXTERN_C_END",
            "IMPELLER_NULLABLE",
            "IMPELLER_NONNULL",
            "IMPELLER_NODISCARD",
            "IMPELLER_NO_EXPORT",
        }:
            continue
        macros.append(
            {
                "name": name,
                "params": match.group("params"),
                "value": normalize_space(match.group("value")),
            }
        )
    return macros


def parse_enums(text: str) -> list[dict[str, Any]]:
    enums: list[dict[str, Any]] = []
    pattern = re.compile(
        r"typedef\s+enum\s+(?P<name>Impeller[A-Za-z0-9_]+)\s*"
        r"\{(?P<body>.*?)\}\s*(?P=name)\s*;",
        re.S,
    )
    for match in pattern.finditer(text):
        body = strip_comments(match.group("body"))
        values = []
        for item in split_comma_list(body):
            item = item.strip()
            if not item:
                continue
            if "=" in item:
                name, value = item.split("=", 1)
                values.append({"name": name.strip(), "value": value.strip()})
            else:
                values.append({"name": item.strip(), "value": None})
        enums.append({"name": match.group("name"), "values": values})
    return enums


def parse_structs(text: str) -> list[dict[str, Any]]:
    structs: list[dict[str, Any]] = []
    pattern = re.compile(
        r"typedef\s+struct\s+(?P<name>Impeller[A-Za-z0-9_]+)\s*"
        r"\{(?P<body>.*?)\}\s*(?P=name)\s*;",
        re.S,
    )
    for match in pattern.finditer(text):
        body = strip_comments(match.group("body"))
        fields = []
        for field in body.split(";"):
            field = clean_decl(field)
            if field:
                fields.append(field)
        structs.append({"name": match.group("name"), "fields": fields})
    return structs


def parse_callbacks(text: str) -> list[dict[str, Any]]:
    callbacks: list[dict[str, Any]] = []
    clean_text = strip_comments(text)
    pattern = re.compile(
        r"typedef\s+(?P<return_type>[^;{}]+?)\(\s*\*\s*(?P<name>Impeller[A-Za-z0-9_]+)\s*\)"
        r"\s*\((?P<params>.*?)\)\s*;",
        re.S,
    )
    for match in pattern.finditer(clean_text):
        params = [clean_decl(param) for param in split_comma_list(match.group("params"))]
        callbacks.append(
            {
                "name": match.group("name"),
                "return_type": clean_decl(match.group("return_type")),
                "params": [param for param in params if param and param != "void"],
            }
        )
    return callbacks


def parse_functions(text: str) -> list[dict[str, Any]]:
    functions: list[dict[str, Any]] = []
    pattern = re.compile(r"\bIMPELLER_EXPORT\b(?P<decl>.*?;)", re.S)
    for match in pattern.finditer(text):
        raw_decl = normalize_space(strip_comments(match.group("decl")))
        parsed = re.match(
            r"(?P<return_type>.+?)\s+(?P<name>Impeller[A-Za-z0-9_]+)\s*"
            r"\((?P<params>.*)\)\s*;",
            raw_decl,
        )
        if not parsed:
            continue

        return_type = clean_decl(parsed.group("return_type"))
        raw_params = split_comma_list(parsed.group("params"))
        params = []
        for raw_param in raw_params:
            clean_param = clean_decl(raw_param)
            if not clean_param or clean_param == "void":
                continue
            name_match = re.search(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*(?:\[[^\]]*\])?$", clean_param)
            params.append(
                {
                    "name": name_match.group(1) if name_match else "",
                    "type": clean_param[: name_match.start(1)].strip() if name_match else clean_param,
                    "decl": clean_param,
                }
            )

        functions.append(
            {
                "name": parsed.group("name"),
                "return_type": return_type,
                "params": params,
                "signature": f"{return_type} {parsed.group('name')}({', '.join(param['decl'] for param in params)})",
            }
        )
    return functions


def export_header(header: Path) -> dict[str, Any]:
    text = header.read_text(encoding="utf-8")
    return {
        "header": str(header),
        "macros": parse_macros(text),
        "handles": parse_handles(text),
        "enums": parse_enums(text),
        "structs": parse_structs(text),
        "callbacks": parse_callbacks(text),
        "functions": parse_functions(text),
    }


def write_markdown(data: dict[str, Any]) -> str:
    lines = [
        "# Impeller SDK Header Export",
        "",
        f"Source: `{data['header']}`",
        "",
        "## Summary",
        "",
        f"- Handles: {len(data['handles'])}",
        f"- Macros: {len(data['macros'])}",
        f"- Enums: {len(data['enums'])}",
        f"- Structs: {len(data['structs'])}",
        f"- Callbacks: {len(data['callbacks'])}",
        f"- Functions: {len(data['functions'])}",
        "",
        "## Macros",
        "",
    ]

    for macro in data["macros"]:
        params = macro["params"] or ""
        if macro["value"]:
            lines.append(f"- `{macro['name']}{params} = {macro['value']}`")
        else:
            lines.append(f"- `{macro['name']}{params}`")

    lines.extend(
        [
            "",
        "## Handles",
        "",
        ]
    )

    for handle in data["handles"]:
        lines.append(f"- `{handle}`")

    lines.extend(["", "## Enums", ""])
    for enum in data["enums"]:
        lines.append(f"### `{enum['name']}`")
        lines.append("")
        for value in enum["values"]:
            if value["value"] is None:
                lines.append(f"- `{value['name']}`")
            else:
                lines.append(f"- `{value['name']} = {value['value']}`")
        lines.append("")

    lines.extend(["## Structs", ""])
    for struct in data["structs"]:
        lines.append(f"### `{struct['name']}`")
        lines.append("")
        lines.append("```c")
        for field in struct["fields"]:
            lines.append(f"{field};")
        lines.append("```")
        lines.append("")

    lines.extend(["## Callbacks", ""])
    for callback in data["callbacks"]:
        params = ", ".join(callback["params"]) if callback["params"] else "void"
        lines.append(f"- `{callback['return_type']} (*{callback['name']})({params})`")

    lines.extend(["", "## Functions", ""])
    for function in data["functions"]:
        lines.append(f"- `{function['signature']}`")

    lines.append("")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--header",
        type=Path,
        default=DEFAULT_HEADER,
        help=f"Path to impeller.h. Defaults to {DEFAULT_HEADER}.",
    )
    parser.add_argument(
        "--format",
        choices=("markdown", "json"),
        default="markdown",
        help="Output format.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Optional output path. Prints to stdout when omitted.",
    )
    args = parser.parse_args()

    data = export_header(args.header)
    if args.format == "json":
        output = json.dumps(data, indent=2)
    else:
        output = write_markdown(data)

    if args.output:
        args.output.write_text(output + "\n", encoding="utf-8")
    else:
        print(output)


if __name__ == "__main__":
    main()
