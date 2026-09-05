#!/usr/bin/env python3
"""Print `<module> <package>...` for every module declaring packages for one family.

Read by the `packages` job, which dry-runs each line in a container of that
family. A name that does not resolve is then reported against the module that
wrote it rather than against a union of every list, which is the whole reason
the lines are kept apart. Run from the collection root.

    packages.py <family>

Only modules whose `supports` names the family are read, so the set is the same
one the `collection` leg of that family imports.
"""

import re
import sys
from pathlib import Path

QUOTED = re.compile(r'"([^"]*)"')
# `family "debian" "ubuntu" {` opening either a one-line or a braced gate.
GATE = re.compile(r'^family((?:\s+"[^"]*")+)\s*\{(.*)$')
PACKAGES = re.compile(r"^packages(\s.*)$")


def lists(text, family):
    """Every package name one manifest installs on one family, in file order.

    Outside a gate is every family the module supports; inside one is the
    families it names. Both spellings of a gate are read: the one-liner
    `family "x" { packages ... }` and the braced block over several lines.
    """
    if not re.search(r'^supports .*"%s"' % re.escape(family), text, re.M):
        return []
    # A list may be continued across lines with a trailing backslash, and a
    # `packages` inside a braced gate is indented.
    names, gate, depth = [], None, 0
    for line in text.replace("\\\n", " ").splitlines():
        line = line.strip()
        if not line or line.startswith("//"):
            continue
        if depth:
            # Inside a braced gate: its `packages`, then its closing brace.
            if line.startswith("}"):
                depth, gate = 0, None
                continue
            if gate is not None and family in gate:
                found = PACKAGES.match(line)
                if found:
                    names += QUOTED.findall(found.group(1))
            continue
        opened = GATE.match(line)
        if opened:
            gate = QUOTED.findall(opened.group(1))
            rest = opened.group(2).strip()
            if rest.endswith("}"):
                # A one-liner: the whole gate is on this line.
                if family in gate:
                    found = PACKAGES.match(rest[:-1].strip())
                    if found:
                        names += QUOTED.findall(found.group(1))
                gate = None
            else:
                depth = 1
            continue
        found = PACKAGES.match(line)
        if found:
            names += QUOTED.findall(found.group(1))
    return names


def main(argv):
    if len(argv) != 2:
        sys.exit(__doc__)
    family = argv[1]
    for manifest in sorted(Path(".").rglob("module.kdl")):
        if any(part.startswith(".") for part in manifest.parts[:-1]):
            continue
        names = lists(manifest.read_text(), family)
        if names:
            print(manifest.parent.as_posix(), *names)


if __name__ == "__main__":
    main(sys.argv)
