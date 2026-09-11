# Agent instructions for tc_benchmark

## Reading program results in scripts (do NOT parse stdout)
- Shell scripts (`benchmark.sh`, `verify.sh`) must obtain each run's metrics from
  the binary's **`TC_CSV=<file>`** output, never by parsing stdout. Every binary
  writes its single 15-column data row (no sentinel) to `TC_CSV` via
  `tc_print_row`. The scripts read that file (`cut`/`read`), so results are immune
  to stray stdout, driver/library messages, and `awk`/`grep` dialect differences.
- **Never use `awk` or `grep` on program stdout** to extract results. This class
  of parsing repeatedly produced spurious `BADLINE:`/`72`/`48`/`24` rows across
  environments. Use the `TC_CSV` file.
- Column order in the `TC_CSV` file (1-indexed): `version,input,iterations(3),
  tc(4),total_time(5),fileio(6),h2d(7),setup(8),build(9),compute(10),
  compute_min(11),d2h(12),peak_mem_mb(13),repeats(14),data(15)`.
- Tuple-level correctness (`verify.sh`) uses **`TC_DUMP=<file>`** (one `src dst`
  per line) + `sort`/`diff` against the MNMGDatalog reference — also file-based.

## Charts
- Whenever you generate a chart locally, always emit **both `.png` and `.pdf`**
  for every figure (PNG for quick viewing / README embedding, PDF for
  papers/vector use). The `tests/plot_results.py` `_save()` helper already does
  this — keep it that way, and route all figure saving through `_save()`.
- Generate all charts into `results/charts/` (both formats). `make plot` writes
  there; the committed charts the README renders also live in `results/charts/`.
  The repo-level `../docs/` tree is prose only — never write figures into it.
- The exact figures behind the published numbers are frozen under
  `../results/paper/charts/tc/`; `make plot` never overwrites those.

## Naming
- Never abbreviate the reference version as `mnmg`; always write **MNMGDatalog**.
- Version display names (charts + README):
  - MNMGDatalog (sort-merge)
  - fused operators (host loop)
  - + CUDA Graph (CPU condition)
  - + Conditional CUDA Graph (GPU condition)

## Charts scope
- Keep it to the two figures: `total_time` and `breakdown`. Speedup and peak
  memory are reported as tables in the README, not extra charts.
- Do not put chart titles on the figures; use axis labels and the dataset
  sub-titles only.

## Published numbers
- The CSVs behind every number in the paper are frozen at
  `../results/paper/tc/` (`benchmark_*.csv`, `gpulog_*.csv`). Treat those as
  read-only; a re-run writes a fresh timestamped CSV into `results/` instead.
- Speedups are always reported two ways: compute-only and end-to-end (total).
- `../docs/FIGURE_MAP.md` maps each paper table/figure to the script and CSV that
  produced it — update it if you add or rename a figure.

## Comparing against GPUlog (gdlog, ASPLOS'25)
- `tests/gpulog_compare.sh` (`make gpulog`) runs GPUlog on the SAME graphs and
  writes `results/gpulog_<ts>.csv`. Set `GDLOG_DIR=/path/to/gdlog` (default: a
  sibling checkout). It converts `.bin`->`.txt` via `tests/bin_to_txt.py` when a
  `.txt` is absent (GPUlog reads tab-separated text).
- GPUlog is a THIRD-PARTY binary with no machine-readable output, so parsing its
  stdout with `grep` (`TC time:`, `Path counts`) is acceptable here; this is the
  ONLY place we parse a binary's stdout. Our own binaries still report via `TC_CSV`.
- GPUlog reports fixpoint `compute` time (compare to our `compute` column). It
  covers TC and SG only (no WCC).
