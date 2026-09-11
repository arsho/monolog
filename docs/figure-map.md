# Figure and table map

Every published number traced back to the command that produced it and the CSV
it came from. Frozen CSVs live in [`results/paper/`](https://github.com/arsho/monolog/tree/main/results/paper) and
frozen figures in [`results/paper/charts/`](https://github.com/arsho/monolog/tree/main/results/paper/charts); a re-run
writes a *new* timestamped file into the benchmark's own `results/` and never
overwrites these.

## Tables

### `tab:results` — End-to-end total time (ms) with speedup over MNMGDatalog

One table, three blocks. `total = fileio + h2d + setup + build + compute + d2h`;
the speedup column is `MNMGDatalog_total / best_fused_total`.

| Block | Datasets | Frozen CSV | Command |
|-------|----------|------------|---------|
| **TC** (6 rows) | OL, TG, SF, fe_body, Gnutella31, vsp_finan | `results/paper/tc/benchmark_20260730_191855.csv` | `cd tc_benchmark && make GPU_ARCH=sm_80 benchmark REPEATS=3` |
| **SG** (4 rows) | CA-HepTh, fe_sphere, loc-Brightkite, fe_body | `results/paper/sg/benchmark_20260730_202342.csv` | `cd sg_benchmark && make GPU_ARCH=sm_80 benchmark REPEATS=3` |
| **WCC** (5 rows) | CA-HepTh, WikiTalk, web-Google, as-skitter, roadNet-CA | `results/paper/cc/benchmark_20260730_202724.csv` | `cd cc_benchmark && make GPU_ARCH=sm_80 benchmark REPEATS=3` |

Columns used: `total_time(5)` per version; `iterations(3)` for the *Iters*
column; `tc|sg|cc(4)` for the *Size* column.

### `tab:versions` — the four execution strategies

Descriptive, not measured. Source of truth is the code:
`v0_reference/`, `v1_baseline/`, `v2_cudagraph/`, `v3_conditional/` in each
benchmark, plus `common/<q>_core.cuh`.

### `tab:datalog-engines` — engine comparison

Descriptive. See [`baselines.md`](baselines.md).

## Figures

### `fig:breakdown` — TC per-phase total time breakdown

Stacked absolute bars (bar height = total ms) with a **broken y-axis** per
dataset, so MNMGDatalog's large total shows in the top slice while the zoomed
bottom keeps the fused versions readable. Phases: file IO, data transfer
(H2D+D2H), setup, graph build, compute.

| | |
|---|---|
| Paper file | `figures/cudagraph_breakdown.pdf` |
| Frozen | `results/paper/charts/tc/breakdown.{pdf,png}` |
| Script | `tc_benchmark/tests/plot_results.py` |
| Command | `cd tc_benchmark && make plot` |
| Input | `results/paper/tc/benchmark_20260730_191855.csv` |

### `fig:compute` — fixpoint compute time, TC (top) and SG (bottom)

Log-scale, **cross-engine**: MNMGDatalog, the three fused versions, and GPUlog
side by side. This is the only figure that needs the GPUlog CSVs, and it reaches
across into `../sg_benchmark/results/`.

| | |
|---|---|
| Paper file | `figures/compute.pdf` |
| Frozen | `results/paper/charts/tc/compute.{pdf,png}` |
| Script | `tc_benchmark/tests/plot_compute.py` |
| Command | `cd tc_benchmark && python3 tests/plot_compute.py` |
| Inputs | `results/paper/tc/benchmark_*.csv`, `results/paper/tc/gpulog_20260803_191526.csv`, `results/paper/sg/benchmark_*.csv`, `results/paper/sg/gpulog_20260803_192000.csv` |

Column used: `compute(10)` for our versions; `gpulog_time_s` for GPUlog.

> Requires step 4 of [`reproducibility.md`](reproducibility.md#4-gpulog-comparison)
> to have run first, and the result-size cross-check to have passed.

### `fig:incremental` — streaming WCC

Incremental-maintenance speedup over recompute (top) and latency (bottom) versus
batch size; both axes log-scaled.

| | |
|---|---|
| Paper file | `figures/cc_incremental.pdf` |
| Frozen | `results/paper/charts/cc/incremental.{pdf,png}` |
| Script | `cc_benchmark/tests/plot_incremental.py` |
| Command | `cd cc_benchmark && make GPU_ARCH=sm_80 incremental REPEATS=3 && make plot-incremental` |
| Input | `results/paper/cc/incremental_20260803_140631.csv` |

### `fig:hashset` — one round of the fused hash-set update

Hand-drawn schematic, not generated from data.

| | |
|---|---|
| Paper file | `figures/hashset_draw.pdf` |
| Frozen | `results/paper/charts/tc/hashset_draw.pdf` |
| Editable source | `results/paper/charts/tc/hashset.drawio` (draw.io / diagrams.net) |

### `fig:workflow` — common engine workflow

Loop-control flowchart: read → H2D → device-resident fixpoint → D2H.

| | |
|---|---|
| Paper file | `figures/workflow.pdf` |
| Frozen | `results/paper/charts/tc/workflow.{pdf,png}` |
| Script | `tc_benchmark/tests/make_flowchart.py` |
| Command | `cd tc_benchmark && python3 tests/make_flowchart.py` |

A more detailed variant that spells out the per-version differences is generated
by `tests/make_flowchart_verbose.py` into `workflow_verbose.{pdf,png}`; it is not
used in the paper.

## Figures generated but not in the paper

| Figure | Where | Why kept |
|--------|-------|----------|
| `total_time.{pdf,png}` (TC/SG/CC) | `results/paper/charts/*/` | Log-scale end-to-end chart rendered in each benchmark's own README |
| `breakdown.{pdf,png}` (SG/CC) | `results/paper/charts/{sg,cc}/` | Per-phase breakdown for the two queries whose breakdown the paper omits |
| `workflow_verbose.{pdf,png}` | `results/paper/charts/tc/` | Expanded version-difference flowchart |

## Claims that come from prose, not a figure

| Claim | Source |
|-------|--------|
| GPUlog compute speedup "up to 29×" (TC), "3.6–6.3×" (SG) | `results/paper/{tc,sg}/gpulog_*.csv` vs. the `compute(10)` column of the matching `benchmark_*.csv` |
| "up to 35× compute" (TC), "up to ~2700×" (WCC) | `compute(10)` ratios in the respective `benchmark_*.csv` |
| "+cond setup ~330 ms vs ~12 ms" | `setup(8)` column, TC CSV, v3 rows |
| "one-shot 17–21 GB result set" | `peak_mem_mb(13)` column, TC CSV |
| "incremental WCC up to 40× cheaper" | `results/paper/cc/incremental_20260803_140631.csv` |

## Regenerating everything

```bash
bash scripts/run_all.sh
```

Then diff the fresh `<benchmark>/results/*.csv` against the frozen
`results/paper/*/*.csv`. Expect run-to-run jitter in the timing columns;
`iterations` and the result-size columns must match exactly.
