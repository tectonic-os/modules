#!/usr/bin/env python3
"""Print the named modules and everything they require, for one family.

A leg that imports a subset of the collection cannot import a diff: a module
whose `requires` nothing in the image provides is an unmet-requires error, so
the set has to be closed over `requires` and `requires-file` against the
providers this family actually has. Run from the collection root.

    closure.py <family> <base> <name>...

A requirement no module here provides is left alone, because the base provides
a MAC policy, `rechunking` and `initramfs-generation` and `tect` is the one that
knows which. Requirements come out before the module that needs them.

What the base's catalog row requires is closed over too, since `create image`
seeds it into every image on that base. It is read from `$TECT_ASSETS/bases.kdl`,
the catalog the leg's own tool carries, because it is a fact about the row and
not the family: Rocky requires `bootc-base` and the other three EL rows do not.
Measured 2026-09-05: a `changed` leg naming one unrelated module scaffolded an
image whose seeded `bootc-base` had nothing providing `container-runtime`.
"""

import os
import re
import sys
from pathlib import Path

DECL = re.compile(r'^\s*(provides|requires)(?:-file)?\s')
QUOTED = re.compile(r'"([^"]*)"')
ROW = re.compile(r'^base "([^"]+)"')


def row_requires(catalog, image):
    """What the row for `image` requires. A digest pins a catalogued tag, and
    a base with no row fails: seeding nothing is the 2026-09-05 defect again."""
    image, row, found, out = image.split("@")[0], None, False, []
    for line in catalog.read_text().splitlines():
        match = ROW.match(line)
        if match:
            row = match.group(1)
            found = found or row == image
        elif line.startswith("}"):
            row = None
        elif row == image and line.lstrip().startswith("requires "):
            out += QUOTED.findall(line)
    if not found:
        sys.exit(f"closure.py: {catalog} has no row for {image}")
    return out


def read(path):
    supports, provides, requires = set(), set(), set()
    for line in path.read_text().splitlines():
        names = QUOTED.findall(line)
        if not names:
            continue
        if line.startswith("supports "):
            supports.update(names)
        elif DECL.match(line):
            which = provides if line.lstrip().startswith("provides") else requires
            which.update(names)
    return supports, provides, requires


def main(argv):
    if len(argv) < 3:
        sys.exit(__doc__)
    family, base, wanted = argv[1], argv[2], argv[3:]
    catalog = Path(os.environ.get("TECT_ASSETS", "")) / "bases.kdl"
    if not catalog.is_file():
        sys.exit(f"closure.py: no catalog at {catalog}; set TECT_ASSETS")

    modules = {}
    for manifest in sorted(Path(".").rglob("module.kdl")):
        name = manifest.parent.as_posix()
        if any(part.startswith(".") for part in manifest.parts[:-1]):
            continue
        modules[name] = read(manifest)

    provider = {}
    for name in sorted(modules):
        supports, provides, _ = modules[name]
        if family not in supports:
            continue
        for capability in sorted(provides):
            provider.setdefault(capability, name)

    # A capability a named module provides is met by that module, so a diff
    # touching one of two providers never pulls in the other.
    for name in wanted:
        if name in modules and family in modules[name][0]:
            for capability in modules[name][1]:
                provider[capability] = name

    order, seen = [], set()

    def visit(name):
        if name in seen:
            return
        seen.add(name)
        for capability in sorted(modules[name][2]):
            needed = provider.get(capability)
            if needed and needed != name:
                visit(needed)
        order.append(name)

    for capability in row_requires(catalog, base):
        seeded = provider.get(capability)
        if seeded:
            visit(seeded)
    for name in wanted:
        if name in modules and family in modules[name][0]:
            visit(name)
    for name in order:
        print(name)


if __name__ == "__main__":
    main(sys.argv)
