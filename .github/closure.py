#!/usr/bin/env python3
"""Print the named modules and everything they require, for one family.

A leg that imports a subset of the collection cannot import a diff: a module
whose `requires` nothing in the image provides is an unmet-requires error, so
the set has to be closed over `requires` and `requires-file` against the
providers this family actually has. Run from the collection root.

    closure.py <family> <name>...

A requirement no module here provides is left alone, because the base provides
a MAC policy, `rechunking` and `initramfs-generation` and `tect` is the one that
knows which. Requirements come out before the module that needs them.
"""

# What the base row itself requires, which `create image` seeds into every image
# on it. Nothing in `wanted` need mention the seeded module, and it has
# requirements of its own -- `deb-family/bootc-base` requires
# `container-runtime` -- so the seed is closed over here rather than left to a
# leg that happens to name it. Measured 2026-09-05: a `changed` leg naming one
# unrelated module scaffolded an image whose seeded `bootc-base` had nothing
# providing `container-runtime`.
SEEDED = {"debian": ("bootc-base",), "ubuntu": ("bootc-base",)}

import re
import sys
from pathlib import Path

DECL = re.compile(r'^\s*(provides|requires)(?:-file)?\s')
QUOTED = re.compile(r'"([^"]*)"')


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
    if len(argv) < 2:
        sys.exit(__doc__)
    family, wanted = argv[1], argv[2:]

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

    for capability in SEEDED.get(family, ()):
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
