#!/usr/bin/env bash
# ******************************************************************************
# Copyright 2025 UChicago Argonne, LLC.
# (c.f. AUTHORS, LICENSE)
#
# This file is part of the monolog project.
# For more info, see https://github.com/arsho/monolog
#
# SPDX-License-Identifier: BSD-3-Clause
# ******************************************************************************
# Reproduce every result in the paper, in order.
#
#   bash scripts/run_all.sh
#
# Env:
#   GPU_ARCH    target architecture      (default sm_80, the A100 used in the paper)
#   REPEATS     timed runs per version   (default 3, what the paper used)
#   SKIP_GPULOG set to 1 to skip the third-party GPUlog comparison
#   SKIP_TEST   set to 1 to skip the correctness gate (NOT recommended)
#
# Stages:
#   1. correctness  - v1-v3 must reproduce v0's result tuple for tuple
#   2. benchmarks   - TC, SG, WCC timings   -> <bench>/results/benchmark_<ts>.csv
#   3. streaming    - incremental WCC       -> cc_benchmark/results/incremental_<ts>.csv
#   4. charts       - per-benchmark figures -> <bench>/results/charts/
#   5. GPUlog       - cross-engine compute  -> <bench>/results/gpulog_<ts>.csv
#   6. cross-engine compute chart (needs stage 5)
#
# Nothing here overwrites results/paper/ - those are the frozen published files.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

GPU_ARCH="${GPU_ARCH:-sm_80}"
REPEATS="${REPEATS:-3}"
SKIP_GPULOG="${SKIP_GPULOG:-0}"
SKIP_TEST="${SKIP_TEST:-0}"
BENCHES=(tc_benchmark sg_benchmark cc_benchmark)

stage() { printf '\n\033[1m=== %s ===\033[0m\n' "$*"; }

stage "Environment"
bash scripts/check_env.sh || {
    echo "Environment check failed. Fix the errors above, or re-run with the" >&2
    echo "restricted dataset list if this is a smaller GPU." >&2
    exit 1
}
echo "GPU_ARCH=$GPU_ARCH  REPEATS=$REPEATS"

if (( SKIP_TEST )); then
    stage "1. Correctness  [SKIPPED]"
    echo "WARNING: timings from an unverified build are not trustworthy." >&2
else
    stage "1. Correctness (v1-v3 must equal the MNMGDatalog reference)"
    for b in "${BENCHES[@]}"; do
        echo "--- $b"
        ( cd "$b" && make GPU_ARCH="$GPU_ARCH" test )
    done
fi

stage "2. Timed benchmarks (tab:results)"
for b in "${BENCHES[@]}"; do
    echo "--- $b"
    ( cd "$b" && make GPU_ARCH="$GPU_ARCH" benchmark REPEATS="$REPEATS" )
done

stage "3. Streaming WCC (fig:incremental)"
( cd cc_benchmark && make GPU_ARCH="$GPU_ARCH" incremental REPEATS="$REPEATS" )

stage "4. Charts (fig:breakdown, per-benchmark total_time)"
for b in "${BENCHES[@]}"; do
    echo "--- $b"
    ( cd "$b" && make plot )
done
( cd cc_benchmark && make plot-incremental )

if (( SKIP_GPULOG )); then
    stage "5. GPUlog comparison  [SKIPPED]"
else
    stage "5. GPUlog comparison (third-party baseline)"
    if [[ ! -f third_party/gdlog/CMakeLists.txt && -z "${GDLOG_DIR:-}" ]]; then
        echo "No gdlog checkout. Fetching the pinned baseline ..."
        bash scripts/setup_gdlog.sh
    fi
    # A stale CMake cache silently drops the injected -std=c++17. See BASELINES.md.
    rm -rf "${GDLOG_DIR:-third_party/gdlog}/build"
    for b in tc_benchmark sg_benchmark; do
        echo "--- $b"
        ( cd "$b" && make GPU_ARCH="$GPU_ARCH" gpulog REPEATS="$REPEATS" )
    done

    stage "6. Cross-engine compute chart (fig:compute)"
    ( cd tc_benchmark && python3 tests/plot_compute.py )
fi

stage "Done"
cat <<EOF
Fresh results:
  tc_benchmark/results/    benchmark_<ts>.csv, gpulog_<ts>.csv, charts/
  sg_benchmark/results/    benchmark_<ts>.csv, gpulog_<ts>.csv, charts/
  cc_benchmark/results/    benchmark_<ts>.csv, incremental_<ts>.csv, charts/

Compare against the frozen published files in results/paper/. Expect run-to-run
jitter in the timing columns; iteration counts and result sizes must match
exactly. See docs/FIGURE_MAP.md for which file backs which table or figure, and
docs/BASELINES.md for the GPUlog result-size cross-check.
EOF
