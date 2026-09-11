#!/usr/bin/env bash
# ******************************************************************************
# Copyright 2025 UChicago Argonne, LLC.
# (c.f. AUTHORS, LICENSE)
#
# This file is part of the Monolog project.
# For more info, see https://github.com/arsho/monolog
#
# SPDX-License-Identifier: BSD-3-Clause
# ******************************************************************************
# Fetch the GPUlog (gdlog) baseline at the exact commit used for the paper.
#
#   bash scripts/setup_gdlog.sh              # clone/pin into third_party/gdlog
#   bash scripts/setup_gdlog.sh --rebuild    # also wipe a stale CMake build dir
#
# GPUlog is third-party MIT-licensed code (HARP Lab) and is deliberately NOT
# vendored into this repository. It is only needed for `make gpulog`; the TC, SG
# and WCC benchmarks run without it.
#
# If this repository is under git, prefer a submodule (see docs/baselines.md):
#   git submodule add https://github.com/harp-lab/gdlog third_party/gdlog
#   git -C third_party/gdlog checkout $GDLOG_COMMIT
#
# The build itself is done by tests/gpulog_compare.sh, which injects
# -DCMAKE_CXX_STANDARD=17 / -DCMAKE_CUDA_STANDARD=17 without modifying any gdlog
# file (modern CCCL/CUB hard-errors otherwise). Do not build gdlog by hand
# unless you pass those flags yourself.

set -euo pipefail

GDLOG_REPO="${GDLOG_REPO:-https://github.com/harp-lab/gdlog}"
GDLOG_COMMIT="${GDLOG_COMMIT:-65a6ee960ced8d04bc725ccdfa68f004f8479226}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${GDLOG_DIR:-$ROOT_DIR/third_party/gdlog}"
REBUILD=0
[[ "${1:-}" == "--rebuild" ]] && REBUILD=1

command -v git >/dev/null 2>&1 || { echo "git is required" >&2; exit 1; }

if [[ -d "$DEST/.git" ]]; then
    echo "gdlog already present at $DEST"
    git -C "$DEST" fetch --quiet origin || true
else
    echo "Cloning gdlog into $DEST"
    mkdir -p "$(dirname "$DEST")"
    git clone --quiet "$GDLOG_REPO" "$DEST"
fi

echo "Pinning to $GDLOG_COMMIT"
git -C "$DEST" checkout --quiet "$GDLOG_COMMIT"

ACTUAL="$(git -C "$DEST" rev-parse HEAD)"
if [[ "$ACTUAL" != "$GDLOG_COMMIT" ]]; then
    echo "ERROR: expected $GDLOG_COMMIT but HEAD is $ACTUAL" >&2
    exit 1
fi

# A CMake cache from an earlier configure keeps the wrong C++ standard and makes
# the harness's injected flags a no-op. This is gotcha #2 in docs/baselines.md.
if (( REBUILD )) && [[ -d "$DEST/build" ]]; then
    echo "Removing stale build directory $DEST/build"
    rm -rf "$DEST/build"
elif [[ -d "$DEST/build" ]]; then
    echo "NOTE: $DEST/build exists. If the GPUlog build fails with"
    echo "      'CUB requires at least C++17', re-run with --rebuild."
fi

cat <<EOF

gdlog pinned at $GDLOG_COMMIT
  $DEST

The benchmark harness finds it automatically (it probes ../third_party/gdlog).
Run the comparison with:

  cd tc_benchmark && make GPU_ARCH=\${GPU_ARCH:-sm_80} gpulog REPEATS=3
  cd sg_benchmark && make GPU_ARCH=\${GPU_ARCH:-sm_80} gpulog REPEATS=3

Then validate the run with the result-size cross-check in docs/baselines.md
before reporting any timing.
EOF
