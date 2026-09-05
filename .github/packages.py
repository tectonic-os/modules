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

BLOCK = re.compile(r"^packages \{\n(.*?)^\}", re.M | re.S)
QUOTED = re.compile(r'"([^"]*)"')


def lists(text, family):
    """The package names one manifest declares for one family, or []."""
    if not re.search(r'^supports .*"%s"' % re.escape(family), text, re.M):
        return []
    block = BLOCK.search(text)
    if not block:
        return []
    # A batch may be continued across lines with a trailing backslash.
    body = block.group(1).replace("\\\n", " ")
    for line in body.splitlines():
        line = line.strip()
        if line.startswith(family + " "):
            return QUOTED.findall(line)
    return []


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
