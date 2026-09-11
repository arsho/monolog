# ******************************************************************************
# Copyright 2025 UChicago Argonne, LLC.
# (c.f. AUTHORS, LICENSE)
#
# This file is part of the monolog project.
# For more info, see https://github.com/arsho/monolog
#
# SPDX-License-Identifier: BSD-3-Clause
# ******************************************************************************
#
# Container image for building and running the monolog benchmarks.
#
#   docker build -t monolog -f environment/Dockerfile .
#   docker run --gpus all -it --rm -v "$PWD:/opt/monolog" monolog
#
# Requires the NVIDIA Container Toolkit. The image pins the toolchain but NOT the
# GPU: results still depend on the device you run against. Published numbers are
# from an A100-PCIE-40GB (sm_80).
#
# CUDA 12.9.1 matches the paper. v3 needs >= 12.4 for conditional graph nodes.

FROM nvidia/cuda:12.9.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Chicago

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        coreutils \
        curl \
        git \
        python3 \
        python3-pip \
        wget \
    && rm -rf /var/lib/apt/lists/*

# Charting dependencies only; nothing here is on the timing path.
COPY requirements.txt /tmp/requirements.txt
RUN python3 -m pip install --no-cache-dir -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

# A100 = sm_80. Override at build or run time for a different card.
ENV GPU_ARCH=sm_80
ENV GPU_ARCH_NUM=80

ARG USER=monolog
RUN useradd -m -s /bin/bash "$USER"

WORKDIR /opt/monolog
COPY --chown=monolog:monolog . /opt/monolog
USER monolog

# Sanity check on start; the datasets ship with the repo, so a bind mount is
# optional and only useful for keeping fresh results on the host.
CMD ["/bin/bash", "-lc", "bash scripts/check_env.sh; exec bash"]
