# Running on JLSE

Exact, copy-pasteable instructions for the ALCF **JLSE** (Joint Laboratory for
System Evaluation) A100 nodes at Argonne National Laboratory — the machine every
published number was produced on.

If you are not on JLSE, use {doc}`quickstart` instead; nothing here is required
elsewhere. The only JLSE-specific parts are the scheduler and the `module`
commands.

## Node

| | |
|---|---|
| CPU | AMD EPYC 7532 |
| GPU | NVIDIA A100-PCIE, 40 GB (`sm_80`) |
| GPUs used | 1 |
| CUDA | `cuda/12.9.1` |

## 1. Reserve a node

JLSE uses Cobalt. Request an A100 node interactively:

```bash
qsub -I -n 1 -t 120 -q gpu_a100 -A <your_project>
```

| Flag | Meaning |
|------|---------|
| `-I` | interactive |
| `-n 1` | one node |
| `-t 120` | 120 minutes — enough for a full `run_all.sh` including `vsp_finan` |
| `-q gpu_a100` | the A100-40GB queue |
| `-A <project>` | your allocation |

Batch instead of interactive:

```bash
qsub -n 1 -t 120 -q gpu_a100 -A <your_project> ./scripts/run_all.sh
```

Confirm you landed on the right hardware before doing anything else:

```bash
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv
# NVIDIA A100-PCIE-40GB, 40960 MiB, <driver>
```

## 2. Load the environment

```bash
module load cuda/12.9.1
module list                # cuda/12.9.1 must be the ACTIVE CUDA
nvcc --version             # release 12.9
export GPU_ARCH=sm_80
```

Or use the helper, which does the same and warns about the `nvhpc` conflict:

```bash
source environment/modules.sh
```

:::{warning}
**Unload `nvhpc` if it is loaded.** It shadows `cuda/12.9.1` and pulls CUDA 13.0
headers into the build — most visibly when compiling the GPUlog baseline, which
then produces numbers from a different toolchain.

```bash
module list 2>&1 | grep -i nvhpc && module unload nvhpc
```
:::

:::{note}
`cuda/12.3.0` is **too old**: `v3` needs CUDA ≥ 12.4 for conditional graph nodes
and will fail to compile.
:::

No `gcc` module is needed — the system compiler handles this `-std=c++17` code.

Python is only needed for charts, never on the timing path:

```bash
python3 -m pip install --user -r requirements.txt
```

## 3. Verify

```bash
bash scripts/check_env.sh
```

Expect: `nvcc 12.9`, an A100 with 40 GB, `GPU_ARCH=sm_80`, no `nvhpc`, 14 datasets
with matching checksums.

## 4. Run

```bash
for b in tc_benchmark sg_benchmark cc_benchmark; do
  ( cd "$b" && make GPU_ARCH=sm_80 test \
             && make GPU_ARCH=sm_80 benchmark REPEATS=3 \
             && make plot )
done
( cd cc_benchmark && make GPU_ARCH=sm_80 incremental REPEATS=3 && make plot-incremental )
```

Then the GPUlog baseline:

```bash
bash scripts/setup_gdlog.sh
rm -rf third_party/gdlog/build          # a stale CMake cache drops the injected -std=c++17
for b in tc_benchmark sg_benchmark; do
  ( cd "$b" && make GPU_ARCH=sm_80 gpulog REPEATS=3 )
done
( cd tc_benchmark && python3 tests/plot_compute.py )
```

All of the above in one command:

```bash
GPU_ARCH=sm_80 REPEATS=3 bash scripts/run_all.sh
```

What each stage produces, and how to interpret it: {doc}`reproducibility`.

## Runtime and footprint

| Stage | Wall clock (A100-40GB) |
|-------|------------------------|
| `make test` (all three) | a few minutes |
| TC `benchmark REPEATS=3` | dominated by `vsp_finan` (~83 s per MNMGDatalog run) |
| SG / WCC `benchmark` | minutes |
| GPUlog build (first time) | several minutes |

Peak device memory reaches **17–21 GB** on the billion-pair TC closures, which is
why a 40 GB card is required for the full dataset list. On a smaller GPU, restrict
the graphs:

```bash
cd tc_benchmark && make GPU_ARCH=sm_80 benchmark DS="data_7035.bin data_23874.bin"
```

`make benchmark` writes no multi-GB result files by default, so disk use stays
small. If you pass `BENCH_KEEP_OUTPUT=1`, budget ~17 GB per large closure and
reclaim it afterwards with `make clean-output`.

## Filesystem

Run from a filesystem with room for the repository (~230 MB, mostly the committed
graphs) plus any result files. Home directories on JLSE are typically quota'd;
project or scratch space is the safer choice for `BENCH_KEEP_OUTPUT=1` runs.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `v3` fails to compile | CUDA < 12.4 | `module load cuda/12.9.1`; check nothing shadows it |
| GPUlog: *"CUB requires at least C++17"* | stale CMake cache | `rm -rf third_party/gdlog/build`, re-run `make gpulog` |
| GPUlog numbers look off | `nvhpc` shadowing CUDA | `module unload nvhpc`, rebuild gdlog |
| Overflow message mid-run | hash set too small for the graph | raise `MULT`; see {doc}`datasets` |
| Wrong architecture at runtime | built with `GPU_ARCH=native` on a differing node | pin `GPU_ARCH=sm_80` |
| Out of memory | GPU smaller than 40 GB | restrict with `DS="..."` |

More detail: {doc}`baselines` for the GPUlog gotchas, {doc}`limitations` for the
capacity model.
