#!/usr/bin/env python3
# ******************************************************************************
# Copyright 2025 UChicago Argonne, LLC.
# (c.f. AUTHORS, LICENSE)
#
# This file is part of the Monolog project.
# For more info, see https://github.com/arsho/monolog
#
# SPDX-License-Identifier: BSD-3-Clause
# ******************************************************************************
"""Insert (or refresh) the Monolog copyright header at the top of source files.

Idempotent: a file that already carries the header is left untouched. Shebang
lines and Python encoding declarations are preserved as the first line(s).

Usage:
    python3 scripts/add_license_headers.py [--check] [paths ...]

    --check   exit 1 if any file is missing the header (for CI); write nothing.

With no paths, walks the repository root and covers *.cu, *.cuh, *.py, *.sh.
"""

import os
import sys

MARKER = "This file is part of the Monolog project."

C_HEADER = """\
/*******************************************************************************
 * Copyright 2025 UChicago Argonne, LLC.
 * (c.f. AUTHORS, LICENSE)
 *
 * This file is part of the Monolog project.
 * For more info, see https://github.com/arsho/monolog
 *
 * SPDX-License-Identifier: BSD-3-Clause
 *****************************************************************************/
"""

HASH_HEADER = """\
# ******************************************************************************
# Copyright 2025 UChicago Argonne, LLC.
# (c.f. AUTHORS, LICENSE)
#
# This file is part of the Monolog project.
# For more info, see https://github.com/arsho/monolog
#
# SPDX-License-Identifier: BSD-3-Clause
# ******************************************************************************
"""

HEADER_FOR_EXT = {
    ".cu": C_HEADER,
    ".cuh": C_HEADER,
    ".cpp": C_HEADER,
    ".h": C_HEADER,
    ".py": HASH_HEADER,
    ".sh": HASH_HEADER,
}

SKIP_DIRS = {".git", "third_party", "__pycache__", ".idea", ".venv", "venv",
             "node_modules", "results"}


def iter_sources(root):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in sorted(filenames):
            ext = os.path.splitext(name)[1]
            if ext in HEADER_FOR_EXT:
                yield os.path.join(dirpath, name)


def apply(path, check=False):
    """Return True if the file was (or would be) modified."""
    header = HEADER_FOR_EXT[os.path.splitext(path)[1]]
    with open(path, "r", encoding="utf-8") as fh:
        text = fh.read()

    if MARKER in text:
        return False
    if check:
        return True

    lines = text.splitlines(keepends=True)
    prefix = []
    # Keep a shebang, and a PEP 263 encoding line, ahead of the header.
    if lines and lines[0].startswith("#!"):
        prefix.append(lines.pop(0))
        if lines and "coding" in lines[0] and lines[0].lstrip().startswith("#"):
            prefix.append(lines.pop(0))

    body = "".join(lines)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("".join(prefix) + header + body)
    return True


def main(argv):
    check = "--check" in argv
    argv = [a for a in argv if a != "--check"]
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    targets = argv or list(iter_sources(root))

    changed = [p for p in targets if apply(p, check=check)]
    for p in changed:
        print(("MISSING " if check else "header  ") + os.path.relpath(p, root))
    if check and changed:
        print(f"\n{len(changed)} file(s) missing the copyright header", file=sys.stderr)
        return 1
    if not check:
        print(f"\n{len(changed)} file(s) updated, "
              f"{len(targets) - len(changed)} already had the header")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
