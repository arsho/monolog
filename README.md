# monolog

**Fused, GPU-resident fixpoint evaluation for recursive graph queries.**

Artifact for *"Accelerating GPU Datalog with Kernel Fusion"* — Ahmedur Rahman
Shovon, Romain Pereira, Yihao Sun, Farhan Saif, Sidharth Kumar, Swann Perarnau.

> *mono* — one fused kernel, one persistent table, one launch.
> *monologue* — the GPU runs the entire fixpoint without a per-round dialogue
> with the host.

Existing GPU Datalog engines execute each round of a recursive query as a chain
of separate operator kernels — join, sort, unique, set-difference, merge — that
rebuild the relation while the host drives the loop. `monolog` replaces that
chain with **one fused kernel over a persistent device-resident structure**: a
single `atomicCAS` (or `atomicMin`) performs deduplication, novelty detection,
and union at once. No sorting, no merging, no per-round allocation. The fused
update yields a scalar change count that stays in device memory, which lets the
whole loop be replayed as a **CUDA graph** or executed from a **single launch**
via a conditional graph node.

This repository is the **single-GPU** version of that work: self-contained,
reproducible, and complete with the datasets, scripts, environment, and frozen
results used in the paper. See [`docs/LIMITATIONS.md`](docs/LIMITATIONS.md) for
what it deliberately does *not* do.

---

## The three queries, the four versions

| Query | Folder | Rule |
|-------|--------|------|
| **Transitive Closure** | [`tc_benchmark/`](tc_benchmark/) | `path(a,c) :- path(a,b), edge(b,c)` |
| **Same Generation** | [`sg_benchmark/`](sg_benchmark/) | `sg(x,y) :- edge(p,x), edge(p,y), x≠y` ; `sg(x,y) :- edge(a,x), sg(a,b), edge(b,y)` |
| **Weakly Connected Components** | [`cc_benchmark/`](cc_benchmark/) | `cc(x,x) :- edge(x,_)` ; `cc(y,c) :- cc(x,c), edge(x,y)` (keep min `c`) |

Each query is implemented four times. All four produce **identical results**,
verified tuple-for-tuple by `make test`; they differ only in *how* the fixpoint
is executed.

| Version | Display name | What changes |
|---------|--------------|--------------|
| **v0** | MNMGDatalog (sort-merge) | Faithful single-GPU port of the reference engine: materialized relational algebra with Thrust `sort`/`unique`/`set_difference`/`merge`, per-iteration `cudaMalloc`/`free`. **Performance reference.** |
| **v1** | fused operators (host loop) | The operator chain fused into **one CUDA kernel** over fixed pre-allocated buffers (open-addressing pair hash set for TC/SG; dense `atomicMin` label array for CC). Host `while` loop. |
| **v2** | + CUDA Graph (CPU condition) | One iteration captured into a CUDA graph and replayed; the host still checks the termination flag. |
| **v3** | + Conditional CUDA Graph (GPU condition) | The whole fixpoint is a CUDA-graph conditional `WHILE` node — **one `cudaGraphLaunch`** runs the entire loop, convergence tested on the device. |

`v0 → v1` is an **algorithm** change. `v1 → v2 → v3` are **execution-strategy**
changes over an identical kernel sequence.

## Headline results

NVIDIA A100-PCIE-40GB, CUDA 12.9.1, median of 3 runs. Speedups are versus
MNMGDatalog (v0). "compute" = fixpoint kernels only; "total" = end-to-end.

| Query | Best total speedup | Best compute speedup | When fusion wins |
|-------|:------------------:|:--------------------:|------------------|
| **TC** | up to **24×** | up to **35×** | grows with iteration count; loses only on very-few-round billion-pair closures |
| **SG** | up to **4.1×** | up to **5.1×** | only on high-iteration graphs; **loses (0.7–0.8×)** on ≤18-round graphs |
| **WCC** | up to **136×** | up to **~2700×** | always, here — dense `atomicMin` crushes materialized min-label |

Against **GPUlog**, on-GPU loop control is up to **29×** faster in fixpoint
compute. Incremental WCC is up to **40×** cheaper than recomputing from scratch.

Two cross-cutting findings:

- **Fusion is the dominant lever**, and its payoff scales with round count. CUDA
  graphs and conditional nodes add a few percent at most, and only when a
  workload is *launch-bound* (many short rounds). Every large workload here is
  compute- or IO-bound, so `+graph`/`+cond` track `fused` closely.
- **Residency is what makes incrementality free.** Because the answer already
  sits in GPU memory and these queries only grow under edge insertions, a new
  batch is absorbed by continuing from the current answer.

Per-query tables, charts, and analysis live in each benchmark's own README.
The exact CSVs and figures behind every published number are frozen under
[`results/paper/`](results/paper) and are never overwritten by a re-run.

## Quickstart

**v3 requires CUDA 12.4+** (conditional graph nodes); `cuda/12.9.1` is what the
paper used. A100 = `sm_80`, H100 = `sm_90`.

```bash
source environment/modules.sh     # module load cuda/12.9.1; GPU_ARCH=sm_80
bash scripts/check_env.sh         # nvcc version, arch, VRAM, python deps

cd tc_benchmark
make GPU_ARCH=sm_80 all           # build v0-v3
make test                         # correctness: v1-v3 tuples == v0, byte for byte
make benchmark REPEATS=3          # -> results/benchmark_<ts>.csv
make plot                         # -> results/charts/{total_time,breakdown}.{png,pdf}
```

Reproduce everything (all three queries, the streaming study, the GPUlog
comparison, and all charts) in one shot:

```bash
bash scripts/setup_gdlog.sh       # pinned GPUlog checkout into third_party/
bash scripts/run_all.sh
```

Full step-by-step instructions, including build gotchas and a result-size
cross-check: [`docs/REPRODUCIBILITY.md`](docs/REPRODUCIBILITY.md).

## Layout

```
tc_benchmark/        Transitive Closure       v0-v3, common/tc_core.cuh, tests/, results/
sg_benchmark/        Same Generation          v0-v3, common/sg_core.cuh, tests/, results/
cc_benchmark/        Weakly Connected Comp.   v0-v3, common/cc_core.cuh, tests/, results/
data/                13 graphs as raw int32 (src,dst) pairs + converters + SHA256SUMS
results/paper/       frozen CSVs and figures behind the published numbers
docs/                REPRODUCIBILITY, LIMITATIONS, BASELINES, DATASETS, FIGURE_MAP
environment/         exact software/hardware environment, module script, Dockerfile
scripts/             check_env.sh, setup_gdlog.sh, run_all.sh, add_license_headers.py
third_party/gdlog/   mount point for the pinned GPUlog checkout (not vendored)
```

Each benchmark resolves its inputs as `DATA_DIR=${DATA_DIR:-<benchmark>/../data}`,
so the top-level `data/` is found automatically. Override with `DATA_DIR=` on any
`make` line.

### Timing model (identical across all three queries)

```
TotalTime = FileIO + H2D + Setup + Build + Compute(median) + D2H
```

- **Compute** — median fixpoint time over the timed repeats, **plus** the
  one-shot result materialization. v1–v3 stream-compact their sparse
  set/labels into a dense array; MNMGDatalog densifies inside its timed
  fixpoint. Attributed symmetrically, so compute is apples-to-apples.
- **D2H** — purely the device→host `cudaMemcpy` of the compacted result. The
  host receive-buffer `malloc` is allocation, not transfer, and is excluded.
- **Setup** — one-shot allocation and initialization (hash table / label array
  memset). **Build** — CUDA-graph build and instantiate (v2/v3 only).

### Measurement discipline

Every one of our binaries writes a single 15-column data row to the file named
by `TC_CSV` / `SG_CSV` / `CC_CSV`, and the harness reads **that file** — never
stdout. Tuple-level verification goes through `*_DUMP=<file>` plus `sort`/`diff`.
This makes results immune to stray output, driver messages, and `awk`/`grep`
dialect differences across environments. The single exception is GPUlog, a
third-party binary with no machine-readable output; see
[`docs/BASELINES.md`](docs/BASELINES.md).

## Compared engines

| Engine | Role | How it is provided |
|--------|------|--------------------|
| **MNMGDatalog** | multi-node multi-GPU Datalog engine; its algorithm is the performance reference | vendored as each benchmark's `v0_reference/` |
| **GPUlog** (gdlog, ASPLOS'25) | state-of-the-art GPU Datalog engine with HISA range-indexed relations | pinned external checkout via `scripts/setup_gdlog.sh`; run by `make gpulog` |

Details, pinned commit, and the two build gotchas we hit:
[`docs/BASELINES.md`](docs/BASELINES.md).

## Documentation

| Document | Contents |
|----------|----------|
| [`docs/REPRODUCIBILITY.md`](docs/REPRODUCIBILITY.md) | Step-by-step: environment, correctness, timings, charts, GPUlog comparison |
| [`docs/LIMITATIONS.md`](docs/LIMITATIONS.md) | **Known limitations** — single-GPU scope, fixed capacity, query-specific representation, where fusion loses |
| [`docs/BASELINES.md`](docs/BASELINES.md) | The two compared engines, pinned versions, build gotchas, result-size cross-check |
| [`docs/DATASETS.md`](docs/DATASETS.md) | All 13 graphs: file, edge count, which query uses it, checksum |
| [`docs/FIGURE_MAP.md`](docs/FIGURE_MAP.md) | Paper table/figure → the script and CSV that produced it |
| [`environment/ENVIRONMENT.md`](environment/ENVIRONMENT.md) | Exact hardware, CUDA version, compiler, and Python environment |

## Citing

See [`CITATION.cff`](CITATION.cff).

## License

BSD-3-Clause. Copyright (c) 2025, UChicago Argonne, LLC. See
[`LICENSE`](LICENSE) and [`AUTHORS`](AUTHORS).

## Acknowledgment

We gratefully acknowledge the computing resources provided and operated by the
Joint Laboratory for System Evaluation (JLSE) at Argonne National Laboratory.
This research also used resources of the Argonne Leadership Computing Facility.
The facilities and contributions of Argonne National Laboratory are supported by
the Office of Science of the U.S. Department of Energy under contract number
DE-AC02-06CH11357. This work was funded in part by NSF PPoSS grant CCF-2316157
and NSF SHF grant CCF-2401274.
