# Reproducing the results

Step-by-step instructions to rebuild and re-run every number in the paper. All
three benchmarks (`tc_benchmark/`, `sg_benchmark/`, `cc_benchmark/`), the
streaming study, and the GPUlog comparison are covered.

> The published numbers were produced on an ALCF **JLSE** node: AMD EPYC 7532
> CPU, **NVIDIA A100-PCIE (40 GB)**, **`cuda/12.9.1`**. `v3` requires CUDA
> **12.4+** (conditional graph nodes). GPUlog builds under 12.x/13.x once C++17
> is forced — see [GPUlog comparison](#4-gpulog-comparison).
>
> Full environment record: {doc}`environment`. Exact instructions for the JLSE
> A100 nodes, including the scheduler and module commands: {doc}`jlse`.

## 0. Environment

```bash
nvcc --version                   # must be >= 12.4
nvidia-smi                       # confirm the GPU and its memory
export GPU_ARCH=sm_80            # sm_80 = A100, sm_90 = H100, or native

python3 -m pip install -r requirements.txt   # matplotlib etc., for `make plot`
bash scripts/check_env.sh        # verifies nvcc, arch, VRAM, datasets, python deps
```

On a cluster where CUDA comes from environment modules, load it first;
`environment/modules.sh` does that and warns about toolchain conflicts.

Notes:

- Datasets are already in [`data/`](https://github.com/arsho/monolog/tree/main/data); nothing to download. Each
  benchmark probes `DATA_DIR=${DATA_DIR:-<benchmark>/../data}`, so the top-level
  `data/` is found automatically. Override with `DATA_DIR=/path` on any `make`.
- Build architecture: `GPU_ARCH=sm_80` for the A100. The default is `native`,
  which also works, but pin `sm_80` for reproducibility.
- No `gcc` module is needed; the system compiler builds this `-std=c++17` code.
- All metrics come from each binary's `*_CSV` file, **never** stdout — see the
  per-benchmark `AGENTS.md`.

## 1. Correctness first (fast)

Each `make test` builds all four versions and verifies they produce
**byte-identical** result tuples against the MNMGDatalog reference (v0). Run this
before trusting any timing.

```bash
cd tc_benchmark && make GPU_ARCH=sm_80 test && cd ..
cd sg_benchmark && make GPU_ARCH=sm_80 test && cd ..
cd cc_benchmark && make GPU_ARCH=sm_80 test && cd ..
```

- **TC / SG** — byte-identical tuple sets (sorted `diff`) *and* identical
  iteration counts.
- **CC** — byte-identical `(node, component)` labelings and node counts. Round
  counts are reported but **not** required to match: order-independent
  `atomicMin` converges in fewer rounds, yet min-label has a unique fixpoint, so
  the final labeling is identical.

A version passes only if its **full tuple set** matches v0's — not merely the
same count.

## 2. Timed benchmarks (the paper's tables and figures)

```bash
# TC  -> results/benchmark_<ts>.csv   (tab:results, fig:breakdown, fig:compute[TC])
cd tc_benchmark && make GPU_ARCH=sm_80 benchmark REPEATS=3 && cd ..

# SG  -> results/benchmark_<ts>.csv   (tab:sgcc[SG], fig:compute[SG])
cd sg_benchmark && make GPU_ARCH=sm_80 benchmark REPEATS=3 && cd ..

# WCC -> results/benchmark_<ts>.csv   (tab:sgcc[WCC])
cd cc_benchmark && make GPU_ARCH=sm_80 benchmark REPEATS=3 && cd ..
```

Each writes a timestamped CSV into that benchmark's `results/`. Column order
(1-indexed) is documented in the benchmark's `AGENTS.md`:

```
version, input, iterations(3), tc|sg|cc(4), total_time(5), fileio(6), h2d(7),
setup(8), build(9), compute(10), compute_min(11), d2h(12), peak_mem_mb(13),
repeats(14), data(15)
```

with `total = fileio + h2d + setup + build + compute + d2h`.

`make benchmark` runs with `*_NO_OUTPUT=1` by default: the device→host transfer
is still timed as `D2H`, so numbers are identical, but **no multi-GB result files
are written**. In this mode `fileio` is the input read only. Pass
`BENCH_KEEP_OUTPUT=1` to also write and keep the result files, in which case
`fileio` includes the write for every version.

Override the dataset list on any target with `DS="data_7035.bin data_23874.bin"`.

### WCC incremental / streaming study

```bash
cd cc_benchmark && make GPU_ARCH=sm_80 incremental REPEATS=3   # incremental_<ts>.csv
```

Splits each graph into a base (first `1-f` of the edge list) plus an insertion
batch (last `f`), then times incremental maintenance against full recomputation,
gating on identical labelings.

## 3. Charts

```bash
cd tc_benchmark && make plot && cd ..     # total_time, breakdown -> results/charts/
cd sg_benchmark && make plot && cd ..
cd cc_benchmark && make plot && cd ..
cd cc_benchmark && make plot-incremental && cd ..

# Cross-engine compute chart (TC+SG incl. GPUlog): needs the CSVs from step 4
cd tc_benchmark && python3 tests/plot_compute.py && cd ..
```

Charts are written as **both `.png` and `.pdf`** into each `results/charts/`.
Plot the latest CSV automatically, or pass an explicit one with `CSV=<path>`.

The figures and CSVs behind the *published* numbers are frozen under
[`results/paper/`](https://github.com/arsho/monolog/tree/main/results/paper) and are never overwritten by a re-run —
compare against them rather than replacing them.

## 4. GPUlog comparison

`make gpulog` runs the third-party **GPUlog (gdlog, ASPLOS'25)** engine on the
*same* graphs and writes `results/gpulog_<ts>.csv`. GPUlog reports fixpoint
**compute** time only (no end-to-end), and covers **TC and SG** (no WCC).

```bash
bash scripts/setup_gdlog.sh       # clone + pin into third_party/gdlog
# or point at an existing checkout:  export GDLOG_DIR=~/gdlog

cd tc_benchmark && make GPU_ARCH=sm_80 gpulog REPEATS=3 && cd ..
cd sg_benchmark && make GPU_ARCH=sm_80 gpulog REPEATS=3 && cd ..
```

The harness converts each `.bin` to the tab-separated text GPUlog expects (via
`tests/bin_to_txt.py`) when a `.txt` is not already present, so both tools consume
the identical graph.

**Before reporting any GPUlog timing, run the result-size cross-check** described
in [`baselines.md`](baselines.md#validating-a-gpulog-run-result-size-cross-check).
Build gotchas (C++17 injection, stale build dir, `nvhpc` shadowing) are documented
in the same file.

## 5. One-shot recap

Everything above, in order:

```bash
bash scripts/run_all.sh
```

which is equivalent to:

```bash
export GPU_ARCH=sm_80
bash scripts/setup_gdlog.sh

for b in tc_benchmark sg_benchmark cc_benchmark; do
  ( cd "$b" && make GPU_ARCH=sm_80 test \
             && make GPU_ARCH=sm_80 benchmark REPEATS=3 \
             && make plot )
done
( cd cc_benchmark && make GPU_ARCH=sm_80 incremental REPEATS=3 && make plot-incremental )

rm -rf third_party/gdlog/build
for b in tc_benchmark sg_benchmark; do
  ( cd "$b" && make GPU_ARCH=sm_80 gpulog REPEATS=3 )
done
( cd tc_benchmark && python3 tests/plot_compute.py )
```

## 6. Housekeeping

```bash
cd tc_benchmark
make clean            # remove the four binaries
make clean-output     # remove *_tc.bin result files + results CSV/charts
make distclean        # both
```

Result relations can be many GB — a billion-pair closure is ~17 GB — so
`clean-output` is the fast way to reclaim disk after a `BENCH_KEEP_OUTPUT=1` run.

## 7. If the numbers do not match

Check, in this order:

1. **Correctness first.** If `make test` fails, timings are meaningless.
2. **Right GPU?** The published numbers are A100-PCIE-**40 GB**. A smaller card
   cannot hold the 17–21 GB hash sets of the largest closures.
3. **Right CUDA?** `nvcc --version` must be ≥ 12.4, and `module list` must show
   no `nvhpc` shadowing it.
4. **Right capacity?** An overflow message means the dataset's `ds_mult` is too
   small for this graph — see [`datasets.md`](datasets.md#capacity-sizing).
5. **Expected losses.** Fused SG *should* lose on ≤18-round graphs, and `+cond`
   *should* lose end-to-end on the few-round billion-pair TC closures. Those are
   documented, not regressions — see [`limitations.md`](limitations.md#6-where-the-fused-versions-lose).
