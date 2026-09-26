#!/usr/bin/env python3
"""Print a module's pinned asset fields as an environment file.

Usage: pins.py <module directory>

Maintainers run this script from the collection root when they compile pinned
sources outside an image build. They receive the field names and `{version}`
expansion that `tect` provides inside a module layer.
"""

import re
import sys
from pathlib import Path

ASSET = re.compile(r'^asset\s+"([^"]+)"\s*\{')
FIELD = re.compile(r'^(version|url|sha256)\s+"([^"]*)"')


def pins(text):
    out, name, fields = [], None, {}
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("//"):
            continue
        found = ASSET.match(line)
        if found:
            name, fields = found.group(1), {}
            continue
        if name is None:
            continue
        if line.startswith("}") and fields:
            version = fields.get("version", "")
            for field, value in fields.items():
                out.append(
                    (
                        "ASSET_%s_%s" % (name.upper().replace("-", "_"), field.upper()),
                        value.replace("{version}", version),
                    )
                )
            name, fields = None, {}
            continue
        found = FIELD.match(line)
        if found:
            fields[found.group(1)] = found.group(2)
    return out


def main(argv):
    if len(argv) != 2:
        sys.exit(__doc__)
    text = (Path(argv[1]) / "module.kdl").read_text()
    for name, value in pins(text):
        print("%s=%s" % (name, value))


if __name__ == "__main__":
    main(sys.argv)
