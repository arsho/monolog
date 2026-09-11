# Environment

The exact environment in which every published number was produced, plus the
minimum requirements for reproducing them elsewhere.

## Hardware (as used for the paper)

| Component | Specification |
|-----------|---------------|
| Site | ALCF **JLSE** (Joint Laboratory for System Evaluation), Argonne National Laboratory |
| CPU | AMD EPYC 7532 |
| GPU | **NVIDIA A100-PCIE, 40 GB** (Ampere, `sm_80`) |
| GPUs used | 1 (this artifact is single-GPU by construction) |

## Software (as used for the paper)

| Component | Version |
|-----------|---------|
| CUDA Toolkit | **12.9.1** (`module load cuda/12.9.1`) |
| `nvcc` target | `-arch=sm_80 -O3 -std=c++17 --extended-lambda` |
| Host compiler | system default (no `gcc` module needed for `-std=c++17`) |
| Thrust / CUB | as shipped with CUDA 12.9.1 (used by `v0_reference`) |
| CMake | ≥ 3.18 (only for building the GPUlog baseline) |
| Python | 3.9+ with `matplotlib` (charts only, never on the timing path) |
| Shell | `bash` with GNU coreutils |

## Minimum requirements

| Requirement | Why |
|-------------|-----|
| **CUDA ≥ 12.4** | `v3` uses CUDA-graph **conditional nodes**. `cuda/12.3.0` is too old and will not compile `v3`. `v0`–`v2` build on older toolkits. |
| Recent NVIDIA driver | Conditional graph nodes are also driver-gated. |
| **≥ 40 GB device memory** for the full dataset list | The largest TC closures allocate a 17–21 GB result hash set. Smaller cards can run the smaller graphs via `DS="..."`. |
| Compute capability ≥ 7.0 | `atomicCAS` on 64-bit and the graph APIs. Published results are `sm_80`; `sm_90` and `GPU_ARCH=native` should work but are untested. |
| ~1 GB free disk | More if you run with `BENCH_KEEP_OUTPUT=1` — result relations reach ~17 GB. |

## Setting up

```bash
source environment/modules.sh                # module load + GPU_ARCH
bash   scripts/check_env.sh                  # verify everything above
python3 -m pip install -r requirements.txt   # charting deps
```

`environment/modules.sh` is written for an LMod site like JLSE. On a machine
without modules, drop it and just make sure `nvcc --version` reports ≥ 12.4 and
export `GPU_ARCH` for your card.

## Container

[`Dockerfile`](Dockerfile) builds an image with the toolchain and the Python
charting dependencies:

```bash
docker build -t monolog -f environment/Dockerfile .
docker run --gpus all -it --rm -v "$PWD:/opt/monolog" monolog
```

Requires the NVIDIA Container Toolkit. The container pins CUDA but **not** the
GPU — results still depend on the device you run it against.

## Recording your environment

When reporting a re-run, capture the environment alongside the CSVs:

```bash
{
  date -Is
  uname -a
  nvidia-smi
  nvcc --version
  module list 2>&1
  python3 -c "import matplotlib; print('matplotlib', matplotlib.__version__)"
} > my_environment.txt
```

## Known environment pitfalls

1. **`nvhpc` shadowing CUDA.** If an `nvhpc` module is loaded it can take
   precedence over `cuda/12.9.1` and pull CUDA 13.0 headers into the build —
   most visibly when building the GPUlog baseline. Always check `module list`.
2. **Stale CMake cache for GPUlog.** A previous configure caches the wrong C++
   standard; `rm -rf third_party/gdlog/build` before re-running `make gpulog`.
3. **`GPU_ARCH=native` on a login node.** If you build on a node whose GPU
   differs from the compute node, `native` produces the wrong architecture. Pin
   `GPU_ARCH=sm_80` explicitly.
4. **Python on the timing path.** There is none. `matplotlib` is only needed for
   `make plot`; benchmarks run fine without it.
