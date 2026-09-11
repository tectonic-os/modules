#!/usr/bin/env python3
"""Print the named modules and everything they require, for one family.

A leg that imports a subset of the collection cannot import a diff: a module
whose `requires` nothing in the image provides is an unmet-requires error, so
the set has to be closed over `requires` and `requires-file` against the
providers this family actually has. Run from the collection root.

    closure.py <family> <base> <name>...
    closure.py --split <family> <base> <name>...

`--split` is the collection leg's: modules providing one capability are
alternatives, so it prints `<image> <module>` lines, image 0 the named set with
one provider of each and every later image the rest, closed over its requires.

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


def split(modules, family, names):
    """The named modules in images that each hold one provider of anything: a
    module joins the first image that provides none of what it provides."""
    images = []
    for name in sorted(n for n in names if n in modules and family in modules[n][0]):
        for members, held in images:
            if not modules[name][1] & held:
                members.append(name)
                held.update(modules[name][1])
                break
        else:
            images.append(([name], set(modules[name][1])))
    groups = [members for members, _ in images] or [[]]
    # A module needing what only an alternative provides follows it out of the
    # first image; the later images are closed over their requires anyway.
    changed = True
    while changed:
        changed = False
        first = groups[0]
        held = set().union(*(modules[m][1] for m in first))
        for name in list(first):
            wants = modules[name][2] - held
            home = next((i for i, other in enumerate(groups[1:], 1)
                         if any(wants & modules[m][1] for m in other)), None)
            if home is not None:
                first.remove(name)
                groups[home].append(name)
                changed = True
                break
    return groups


def main(argv):
    splitting = argv[1:2] == ["--split"]
    argv = [argv[0]] + argv[2:] if splitting else argv
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

    seeded_by_row = row_requires(catalog, base)
    if not splitting:
        for name in close(modules, family, seeded_by_row, wanted):
            print(name)
        return
    # The first image is the collection as it stands; each after it holds
    # alternative providers, closed over what they require.
    first, *rest = split(modules, family, wanted)
    for name in first:
        print(f"0 {name}")
    for index, alternates in enumerate(rest, 1):
        for name in close(modules, family, seeded_by_row, alternates):
            print(f"{index} {name}")


def close(modules, family, seeded_by_row, wanted):
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

    for capability in seeded_by_row:
        seeded = provider.get(capability)
        if seeded:
            visit(seeded)
    for name in wanted:
        if name in modules and family in modules[name][0]:
            visit(name)
    return order


if __name__ == "__main__":
    main(sys.argv)
