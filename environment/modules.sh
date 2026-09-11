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
# Load the software environment used for the published results.
#
#   source environment/modules.sh
#
# This must be SOURCED, not executed, so the exports survive.
#
# Site assumption: an LMod/Tcl `module` command (as on ALCF JLSE). On a machine
# without modules the module load is skipped and only GPU_ARCH is exported;
# ensure `nvcc --version` reports 12.4 or newer yourself.
#
# Override the CUDA module or target architecture before sourcing:
#   CUDA_MODULE=cuda/12.4.0 GPU_ARCH=sm_90 source environment/modules.sh

CUDA_MODULE="${CUDA_MODULE:-cuda/12.9.1}"

# A100 = sm_80 (what the paper used). H100 = sm_90. `native` autodetects, but
# pin an explicit arch for reproducibility, especially when the build node and
# the compute node differ.
export GPU_ARCH="${GPU_ARCH:-sm_80}"

# Numeric form of the same architecture, for the GPUlog/CMake build.
export GPU_ARCH_NUM="${GPU_ARCH_NUM:-${GPU_ARCH#sm_}}"

if command -v module >/dev/null 2>&1; then
    module load "$CUDA_MODULE" 2>/dev/null \
        && echo "loaded $CUDA_MODULE" \
        || echo "WARNING: could not load $CUDA_MODULE; using the ambient CUDA"

    # nvhpc can shadow the CUDA module and silently pull in a different CUDA
    # version, which changes the GPUlog baseline build. Warn loudly.
    if module list 2>&1 | grep -qi nvhpc; then
        echo "WARNING: an nvhpc module is loaded and may shadow $CUDA_MODULE." >&2
        echo "         Unload it for toolchain parity with the published runs." >&2
    fi
else
    echo "no 'module' command found; using the ambient CUDA installation"
fi

echo "GPU_ARCH=$GPU_ARCH  GPU_ARCH_NUM=$GPU_ARCH_NUM"
command -v nvcc >/dev/null 2>&1 \
    && nvcc --version | tail -2 \
    || echo "WARNING: nvcc not on PATH" >&2

echo "Next: bash scripts/check_env.sh"
