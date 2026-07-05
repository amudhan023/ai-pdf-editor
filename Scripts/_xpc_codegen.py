#!/usr/bin/env python3
"""Generates Swift DTOs from Schemas/xpc-dtos.yml.

Not a general YAML parser - hand-parses exactly the constrained grammar
documented in Schemas/README.md (2-space indent, no lists, no quoting).
Written this way deliberately rather than depending on PyYAML (CLAUDE.md
SS17: default answer to a new dependency is no; this is ~80 lines of
straight-line parsing for a shape only this repo produces).
"""
import sys

TYPE_MAP = {
    "string": "String",
    "int": "Int",
    "bool": "Bool",
    "date": "Date",
    "data": "Data",
}

BANNER = """\
// GENERATED FILE - DO NOT EDIT.
// Source: Schemas/xpc-dtos.yml
// Regenerate: Scripts/codegen.sh

import Foundation

"""


def parse(text):
    lines = [l for l in text.splitlines() if l.strip() and not l.strip().startswith("#")]
    top = {}
    i = 0

    def indent_of(line):
        return len(line) - len(line.lstrip(" "))

    while i < len(lines):
        line = lines[i]
        if indent_of(line) != 0:
            raise ValueError(f"expected top-level key, got indented line: {line!r}")
        key, _, rest = line.partition(":")
        key = key.strip()
        rest = rest.strip()
        if key == "dtos":
            if rest == "{}":
                top["dtos"] = {}
                i += 1
                continue
            if rest:
                raise ValueError(f"'dtos:' must be followed by nothing or '{{}}', got: {rest!r}")
            dtos = {}
            i += 1
            while i < len(lines) and indent_of(lines[i]) == 2:
                dto_name = lines[i].strip().rstrip(":")
                i += 1
                fields = {}
                if i < len(lines) and indent_of(lines[i]) == 4 and lines[i].strip() == "fields:":
                    i += 1
                    while i < len(lines) and indent_of(lines[i]) == 6:
                        fkey, _, ftype = lines[i].strip().partition(":")
                        fields[fkey.strip()] = ftype.strip()
                        i += 1
                dtos[dto_name] = fields
            top["dtos"] = dtos
            continue
        top[key] = rest
        i += 1
    return top


def swift_type(schema_type, dto_name, field_name):
    if schema_type not in TYPE_MAP:
        raise ValueError(
            f"{dto_name}.{field_name}: unsupported type '{schema_type}' "
            f"(supported: {', '.join(sorted(TYPE_MAP))})"
        )
    return TYPE_MAP[schema_type]


def generate(schema):
    out = [BANNER.rstrip("\n")]
    interface_version = schema.get("interfaceVersion", "v1")
    out.append("")
    out.append("public enum XPCInterfaceVersion {")
    out.append(f'    public static let current = "{interface_version}"')
    out.append("}")

    for dto_name, fields in schema.get("dtos", {}).items():
        out.append("")
        out.append(f"public struct {dto_name}: Codable, Sendable, Equatable {{")
        for fname, ftype in fields.items():
            out.append(f"    public let {fname}: {swift_type(ftype, dto_name, fname)}")
        out.append("")
        init_args = ", ".join(
            f"{fname}: {swift_type(ftype, dto_name, fname)}" for fname, ftype in fields.items()
        )
        out.append(f"    public init({init_args}) {{")
        for fname in fields:
            out.append(f"        self.{fname} = {fname}")
        out.append("    }")
        out.append("}")

    out.append("")
    return "\n".join(out)


def main(argv):
    if len(argv) != 2:
        print("usage: _xpc_codegen.py <schema.yml>", file=sys.stderr)
        return 2
    with open(argv[1]) as f:
        schema = parse(f.read())
    sys.stdout.write(generate(schema))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
