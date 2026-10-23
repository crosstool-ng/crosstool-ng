#!/usr/bin/env python3
"""Check that Kconfig only references milestones declared by packages.

bootstrap generates the <pkg>_<milestone>_{or_later,or_older},
<pkg>_{later,older}_than_<milestone> and <pkg>_REQUIRE_* symbols from the
milestones listed in packages/*/package.desc.  A reference to any other
milestone is silently ignored by Kconfig, which turns the intended
constraint into a no-op.
"""

import argparse
import pathlib
import re
import sys


MILESTONE_PATTERN = re.compile(
    r"\b([A-Z][A-Z0-9_]+?)_"
    r"(?:REQUIRE_)?"
    r"(?:([0-9][A-Za-z0-9_.]*)_(?:or_later|or_older)"
    r"|(later|older)_than_([0-9][A-Za-z0-9_.]*))"
    r"\b"
)


def normalize_milestone(value):
    return re.sub(r"[^A-Za-z0-9]", "_", value).upper()


def parse_package_desc(path):
    desc = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        desc[key.strip()] = value.strip().strip("'\"")
    return desc


def load_packages(root):
    """Return the milestone set per master package and fork-to-master map."""
    milestones = {}
    master_of = {}
    for desc in sorted((root / "packages").glob("*/package.desc")):
        data = parse_package_desc(desc)
        name = desc.parent.name
        master = data.get("master", name)
        master_of[name] = master
        values = {
            normalize_milestone(milestone)
            for milestone in data.get("milestones", "").split()
        }
        milestones.setdefault(master, set()).update(values)
    return milestones, master_of


def find_unresolved(root):
    """Return (file, reference, package, milestone) for unresolved references."""
    root = pathlib.Path(root)
    milestones, master_of = load_packages(root)

    package_by_symbol = {
        normalize_milestone(name): master for name, master in master_of.items()
    }

    unresolved = []
    seen = set()
    for path in sorted((root / "config").rglob("*.in")):
        relative = path.relative_to(root)
        # bootstrap generates these from the sources checked below.
        if relative.parts[:2] in (("config", "gen"), ("config", "versions")):
            continue
        for match in MILESTONE_PATTERN.finditer(path.read_text(errors="replace")):
            package = package_by_symbol.get(match.group(1))
            if package is None:
                continue
            milestone = normalize_milestone(match.group(2) or match.group(4))
            key = (relative, match.group(0))
            if key in seen:
                continue
            seen.add(key)
            if milestone not in milestones.get(package, set()):
                unresolved.append(
                    (str(relative), match.group(0), package, milestone)
                )
    return unresolved


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=pathlib.Path,
        default=pathlib.Path(__file__).resolve().parents[1],
        help="crosstool-NG source tree (default: repository containing this script)",
    )
    args = parser.parse_args()

    unresolved = find_unresolved(args.root.resolve())
    for path, reference, package, milestone in unresolved:
        print(
            f"{path}: {reference} -> {package} milestone "
            f"'{milestone}' is not declared in packages/{package}/package.desc"
        )
    if unresolved:
        print(
            f"\n{len(unresolved)} unresolved milestone reference(s).",
            file=sys.stderr,
        )
        return 1
    print("All milestone references resolve.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
