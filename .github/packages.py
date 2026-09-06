#!/usr/bin/env python3
"""Print `<module> <package>...` for every module declaring packages for one family.

Read by the `packages` job, which dry-runs each line in a container of that
family. A name that does not resolve is then reported against the module that
wrote it rather than against a union of every list, which is the whole reason
the lines are kept apart. Run from the collection root.

    packages.py <family>
    packages.py <family> --repos

`--repos` prints instead every `repo` file this family would source, which the
job runs before it resolves anything: a package out of a third-party archive
cannot be resolved on a base that has never heard of it, and skipping those
modules would leave the widenings most likely to break as the ones nothing
measures. A module declaring no packages is listed too -- one that only turns
a component on is exactly the module the others depend on.

Only modules whose `supports` names the family are read, so the set is the same
one the `collection` leg of that family imports.
"""

import re
import sys
from pathlib import Path

QUOTED = re.compile(r'"([^"]*)"')
# `enablerepo="tailscale-stable"` is a property of the batch and not a package
# in it, so its value is dropped before the names are read.
PROP = re.compile(r'[\w-]+="[^"]*"')
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
                    names += declared(found.group(1))
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
                        names += declared(found.group(1))
                gate = None
            else:
                depth = 1
            continue
        found = PACKAGES.match(line)
        if found:
            names += declared(found.group(1))
    return names


def declared(rest):
    """The package names on one `packages` line, without its properties."""
    return QUOTED.findall(PROP.sub("", rest))


# Widest first and the module root last, which is the order the tool's own
# `layout::family_first` walks: one `repo` is picked, never layered.
FAMILY_DIRS = {
    "debian": ["debian/", "deb/", ""],
    "ubuntu": ["ubuntu/", "deb/", ""],
    "fedora": ["fedora/", ""],
}


def repo(module, family):
    """The `repo` file this module ships for this family, if it ships one."""
    for at in FAMILY_DIRS.get(family, [""]):
        found = module / at / "repo"
        if found.is_file():
            return found
    return None


def main(argv):
    if len(argv) not in (2, 3) or (len(argv) == 3 and argv[2] != "--repos"):
        sys.exit(__doc__)
    family, repos = argv[1], len(argv) == 3
    for manifest in sorted(Path(".").rglob("module.kdl")):
        if any(part.startswith(".") for part in manifest.parts[:-1]):
            continue
        text = manifest.read_text()
        if not re.search(r'^supports .*"%s"' % re.escape(family), text, re.M):
            continue
        if repos:
            found = repo(manifest.parent, family)
            if found:
                print(found.as_posix())
            continue
        names = lists(text, family)
        if names:
            print(manifest.parent.as_posix(), *names)


if __name__ == "__main__":
    main(sys.argv)
