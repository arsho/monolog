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
# Check that this machine can build and run the benchmarks, and report anything
# that would make the results differ from the published ones.
#
#   bash scripts/check_env.sh
#
# Exit status: 0 if everything required is present, 1 if a hard requirement is
# missing. Warnings do not fail the check.

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
WARN=0

ok()   { printf '  \033[32mok\033[0m    %s\n' "$*"; }
warn() { printf '  \033[33mwarn\033[0m  %s\n' "$*"; WARN=$((WARN + 1)); }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$*"; FAIL=$((FAIL + 1)); }
head_() { printf '\n\033[1m%s\033[0m\n' "$*"; }

head_ "CUDA toolkit"
if command -v nvcc >/dev/null 2>&1; then
    NVCC_VER="$(nvcc --version | sed -n 's/.*release \([0-9]*\.[0-9]*\).*/\1/p')"
    NVCC_MAJOR="${NVCC_VER%%.*}"
    NVCC_MINOR="${NVCC_VER##*.}"
    if [[ -z "$NVCC_VER" ]]; then
        warn "could not parse the nvcc version"
    elif (( NVCC_MAJOR > 12 || (NVCC_MAJOR == 12 && NVCC_MINOR >= 4) )); then
        ok "nvcc $NVCC_VER (>= 12.4, conditional graph nodes available)"
        [[ "$NVCC_VER" == "12.9" ]] || warn "the paper used CUDA 12.9.1; you have $NVCC_VER"
    else
        bad "nvcc $NVCC_VER is too old. v3 needs CUDA >= 12.4 for conditional graph nodes."
    fi
else
    bad "nvcc not on PATH. Run: source environment/modules.sh"
fi

head_ "GPU"
if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=index,name,memory.total,driver_version \
               --format=csv,noheader 2>/dev/null | while IFS= read -r line; do
        printf '        %s\n' "$line"
    done
    MEM_MB="$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)"
    if [[ -n "${MEM_MB:-}" ]] && [[ "$MEM_MB" =~ ^[0-9]+$ ]]; then
        if (( MEM_MB >= 39000 )); then
            ok "$((MEM_MB / 1024)) GB device memory (enough for the full dataset list)"
        else
            warn "$((MEM_MB / 1024)) GB device memory. The largest TC closures need a 17-21 GB
        result set on a 40 GB card. Restrict with DS=\"data_7035.bin ...\"."
        fi
    fi
    NGPU="$(nvidia-smi --query-gpu=index --format=csv,noheader 2>/dev/null | wc -l | tr -d ' ')"
    (( NGPU > 1 )) && warn "$NGPU GPUs visible; this artifact uses exactly one (CUDA_VISIBLE_DEVICES=0)"
else
    bad "nvidia-smi not found; no usable GPU detected"
fi

head_ "Target architecture"
: "${GPU_ARCH:=}"
if [[ -n "$GPU_ARCH" ]]; then
    ok "GPU_ARCH=$GPU_ARCH"
    [[ "$GPU_ARCH" == "native" ]] && warn "GPU_ARCH=native picks up the BUILD node's GPU.
        Pin sm_80 (A100) or sm_90 (H100) if build and compute nodes differ."
else
    warn "GPU_ARCH unset; the Makefiles default to 'native'. Pin it: export GPU_ARCH=sm_80"
fi

head_ "Toolchain parity"
if command -v module >/dev/null 2>&1 && module list 2>&1 | grep -qi nvhpc; then
    warn "an nvhpc module is loaded; it can shadow the CUDA module and change the
        GPUlog baseline build. Unload it for parity with the published runs."
else
    ok "no nvhpc module shadowing the CUDA toolkit"
fi

head_ "Build tools"
for t in make bash; do
    command -v "$t" >/dev/null 2>&1 && ok "$t" || bad "$t not found"
done
command -v cmake >/dev/null 2>&1 \
    && ok "cmake $(cmake --version | head -1 | awk '{print $3}') (needed only for the GPUlog baseline)" \
    || warn "cmake not found; needed only to build the GPUlog baseline (make gpulog)"

head_ "Python (charts only, never on the timing path)"
if command -v python3 >/dev/null 2>&1; then
    ok "python3 $(python3 -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])')"
    if python3 -c 'import matplotlib' 2>/dev/null; then
        ok "matplotlib $(python3 -c 'import matplotlib; print(matplotlib.__version__)')"
    else
        warn "matplotlib missing; 'make plot' will fail. pip install -r requirements.txt"
    fi
else
    warn "python3 not found; charts and .bin->.txt conversion will not work"
fi

head_ "Datasets"
DATA_DIR="${DATA_DIR:-$ROOT_DIR/data}"
if [[ -d "$DATA_DIR" ]]; then
    NBIN="$(find "$DATA_DIR" -maxdepth 1 -name '*.bin' | wc -l | tr -d ' ')"
    if (( NBIN >= 13 )); then
        ok "$NBIN .bin graphs in $DATA_DIR"
    else
        warn "only $NBIN .bin graphs in $DATA_DIR (expected 14 incl. the smoke test)"
    fi
    if [[ -f "$DATA_DIR/SHA256SUMS" ]] && command -v shasum >/dev/null 2>&1; then
        if ( cd "$DATA_DIR" && shasum -a 256 -c SHA256SUMS >/dev/null 2>&1 ); then
            ok "all dataset checksums verify"
        else
            bad "dataset checksum mismatch. Run: cd data && shasum -a 256 -c SHA256SUMS"
        fi
    fi
else
    bad "no data directory at $DATA_DIR"
fi

head_ "GPUlog baseline (optional, for 'make gpulog')"
GD=""
for c in "${GDLOG_DIR:-}" "$ROOT_DIR/third_party/gdlog" "$HOME/gdlog"; do
    [[ -n "$c" && -f "$c/CMakeLists.txt" ]] && GD="$c" && break
done
if [[ -n "$GD" ]]; then
    ok "gdlog checkout at $GD"
    [[ -x "$GD/build/TC" ]] && ok "gdlog TC binary already built" \
                            || warn "gdlog not built yet; 'make gpulog' will build it"
else
    warn "no gdlog checkout found. Run: bash scripts/setup_gdlog.sh
        (only needed for the GPUlog comparison; TC/SG/WCC run without it)"
fi

head_ "Disk"
AVAIL="$(df -Pk "$ROOT_DIR" 2>/dev/null | awk 'NR==2 {print int($4/1048576)}')"
if [[ -n "${AVAIL:-}" ]]; then
    (( AVAIL >= 2 )) && ok "${AVAIL} GB free" \
                     || warn "only ${AVAIL} GB free; BENCH_KEEP_OUTPUT=1 runs need much more"
fi

printf '\n'
if (( FAIL > 0 )); then
    printf '\033[31m%d hard requirement(s) missing\033[0m, %d warning(s)\n' "$FAIL" "$WARN"
    exit 1
fi
printf '\033[32mEnvironment OK\033[0m (%d warning(s))\n' "$WARN"
printf 'Next: cd tc_benchmark && make GPU_ARCH=%s test\n' "${GPU_ARCH:-sm_80}"
