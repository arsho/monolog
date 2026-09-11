# Quickstart

## Requirements

| | |
|---|---|
| GPU | NVIDIA, compute capability ≥ 7.0. Published results use an A100-PCIE-40GB (`sm_80`). |
| CUDA | **≥ 12.4** — `v3` uses CUDA-graph conditional nodes. 12.9.1 is what the paper used. |
| Device memory | 40 GB for the full dataset list; the largest closures allocate a 17–21 GB result set. Smaller cards can run smaller graphs via `DS=`. |
| Build | `make`, `bash`, GNU coreutils. `cmake` only for the GPUlog baseline. |
| Python | 3.9+ with `matplotlib`, for charts only. Never on the timing path. |

Full details and known pitfalls: {doc}`environment`.

## Build and run

```bash
git clone https://github.com/arsho/monolog
cd monolog

source environment/modules.sh     # module load cuda/12.9.1; GPU_ARCH=sm_80
bash scripts/check_env.sh         # nvcc version, arch, VRAM, datasets, python deps

cd tc_benchmark
make GPU_ARCH=sm_80 all           # build v0-v3
make test                         # correctness: v1-v3 tuples == v0, byte for byte
make benchmark REPEATS=3          # -> results/benchmark_<ts>.csv
make plot                         # -> results/charts/{total_time,breakdown}.{png,pdf}
```

`sg_benchmark/` and `cc_benchmark/` build and run identically.

Run a single binary directly:

```bash
./v1_baseline/tc_v1.out <data.bin> [capacity_mult] [repeats] [frontier_slots]
```

## Make targets

| Target | Effect |
|--------|--------|
| `all` | Build `v0`–`v3` |
| `test` | Verify `v1`–`v3` reproduce `v0`'s result tuples exactly |
| `benchmark` | Time all four versions, write `results/benchmark_<ts>.csv` |
| `gpulog` | Run the GPUlog baseline on the same graphs (needs `third_party/gdlog`) |
| `plot` | Render charts into `results/charts/` as both `.png` and `.pdf` |
| `incremental` | Streaming WCC study (`cc_benchmark` only) |
| `clean` / `clean-output` / `distclean` | Remove binaries / result files and charts / both |

Useful variables: `GPU_ARCH`, `REPEATS`, `DS="a.bin b.bin"`, `DATA_DIR=/path`,
`MULT`, `CSV=<path>`, `BENCH_KEEP_OUTPUT=1`.

## Reproduce everything

```bash
bash scripts/setup_gdlog.sh       # pinned GPUlog baseline into third_party/
bash scripts/run_all.sh           # all three queries + streaming + charts + GPUlog
```

Step-by-step version: {doc}`reproducibility`.

## Layout

```
tc_benchmark/        Transitive Closure       v0-v3, common/tc_core.cuh, tests/, results/
sg_benchmark/        Same Generation          v0-v3, common/sg_core.cuh, tests/, results/
cc_benchmark/        Weakly Connected Comp.   v0-v3, common/cc_core.cuh, tests/, results/
data/                14 graphs as raw int32 (src,dst) pairs + converters + SHA256SUMS
results/paper/       frozen CSVs and figures behind the published numbers
docs/                this documentation
environment/         module script, Dockerfile
scripts/             check_env.sh, setup_gdlog.sh, run_all.sh
third_party/gdlog/   mount point for the pinned GPUlog checkout (not vendored)
```

Each benchmark resolves inputs as `DATA_DIR=${DATA_DIR:-<benchmark>/../data}`, so
the top-level `data/` is found automatically.

## Timing model

```
TotalTime = FileIO + H2D + Setup + Build + Compute(median) + D2H
```

- **Compute** — median fixpoint time over the timed repeats, plus the one-shot
  result materialization. `v1`–`v3` stream-compact their sparse set or labels into
  a dense array; MNMGDatalog densifies inside its timed fixpoint. Attributed
  symmetrically, so compute is apples-to-apples.
- **D2H** — purely the device→host `cudaMemcpy` of the compacted result. The host
  receive-buffer `malloc` is allocation, not transfer, and is excluded.
- **Setup** — one-shot allocation and initialization (hash table or label array
  memset). **Build** — CUDA-graph build and instantiate (`v2`/`v3` only).

## Measurement discipline

Every binary writes a single 15-column row to the file named by `TC_CSV` /
`SG_CSV` / `CC_CSV`, and the harness reads **that file** — never stdout:

```
version, input, iterations(3), tc|sg|cc(4), total_time(5), fileio(6), h2d(7),
setup(8), build(9), compute(10), compute_min(11), d2h(12), peak_mem_mb(13),
repeats(14), data(15)
```

Tuple-level verification goes through `*_DUMP=<file>` plus `sort`/`diff`. This
makes results immune to stray output, driver messages, and `awk`/`grep` dialect
differences. The single exception is GPUlog, a third-party binary with no
machine-readable output — see {doc}`baselines`.

## Memory and capacity

For TC and SG the result hash set is allocated once as
`next_pow2(n_edges × capacity_mult)` and must hold **≥ ~2× the result size**, or
the run fails fast with an overflow message. Frontier buffers are decoupled
(`min(result_cap, 2^28)` slots each), so only the set grows with the result —
which is what lets billion-pair closures fit in 40 GB. `benchmark.sh` picks a
tuned per-dataset multiplier automatically. Oversizing inflates `setup` and peak
memory, but not `compute`.

See {doc}`datasets` for the per-dataset table and {doc}`limitations` for why
there is no grow-and-rehash.
