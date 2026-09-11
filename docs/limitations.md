# Known limitations

This artifact is a **single-GPU** research prototype, published to make the
paper's numbers reproducible and directly comparable against the two engines we
evaluate. It is not a general-purpose Datalog system. Every limitation below is
deliberate and load-bearing for how the results should be read.

## 1. Scope: one GPU, one node

Everything here targets a **single NVIDIA A100-PCIE (40 GB)**. There is no
multi-GPU or multi-node execution, no partitioning, no communication layer. That
is the domain of MNMGDatalog, the engine vendored here as `v0_reference/`.
Scaling the fused, device-resident design to multi-node is stated future work.

## 2. Fixed capacity, no grow-and-rehash

The result hash set is sized once, up front, as
`next_pow2(n_edges × capacity_mult)`, and must hold **≥ ~2× the final result
size**. There is no dynamic growth: an undersized table fails fast with an
overflow message rather than rehashing.

- `tests/benchmark.sh` carries a hand-tuned per-dataset `ds_mult` table. A graph
  outside that table falls back to the CLI `MULT` and may need tuning.
- Oversizing inflates the `setup` phase (a large `cudaMemset`) and peak memory,
  but not `compute`.
- Estimating the table size from early-round growth, and growing-and-rehashing
  on demand, is future work.

## 3. The result must fit in device memory

There is no spilling to host memory. The largest closures here allocate 17–21 GB
of hash set on a 40 GB card, which is why frontier buffers are decoupled and
capped at `min(result_cap, 2^28)` slots. A closure that exceeds device memory
simply cannot be run. Overlapped spilling of cold regions to a pinned host buffer
is future work.

## 4. The representation is query-specific, not a general engine

The fused pair hash set works **because the derived tuple is the whole key**. One
`atomicCAS` can therefore subsume `unique` + `set_difference` + `merge`. This does
not generalize:

- General multi-column joins still need a range-indexed relation such as
  GPUlog's HISA.
- There is **no rule compiler, no parser, no Datalog frontend**. Three queries
  (TC, SG, WCC) are hand-written in CUDA. Adding a fourth query means writing a
  new `common/<q>_core.cuh`.

The **execution-strategy** contributions (CUDA graph replay, conditional-node
loop control) do transfer to a general engine; the fused storage layout does not.

## 5. Toolchain floor: CUDA 12.4+

`v3` uses CUDA-graph **conditional nodes**, which require **CUDA 12.4 or newer**
and a matching driver. `cuda/12.9.1` is what the paper used; `cuda/12.3.0` is too
old and will fail to compile `v3`. `v0`–`v2` build on older toolkits.

## 6. Where the fused versions lose

The paper reports these honestly and so does this artifact. They are properties
of the design, not bugs:

| Case | Behavior | Cause |
|------|----------|-------|
| **TC, few-round billion-pair closures** (fe_body, p2p-Gnutella31, vsp_finan) | `+cond` posts a *worse* total than `fused`/`+graph` | ~330 ms to initialize conditional-graph state (vs ~12 ms elsewhere), not repaid over so few heavy rounds |
| **SG, ≤18-round graphs** | fused **loses at 0.7–0.8×** | the fused SG kernel re-derives a per-round cross product; with too few rounds the reference's batched Thrust joins win |
| **Any large closure** | non-compute time dominates | a one-shot 17–21 GB `setup` memset plus D2H of hundreds of millions of tuples swamps the fixpoint |
| **Launch-bound workloads only** | `+graph`/`+cond` gain a few percent at most | every large workload here is compute- or IO-bound, so graph capture has little launch overhead left to remove |

## 7. WCC round counts intentionally differ

`make test` in `cc_benchmark` checks that v1–v3 produce a **byte-identical
`(node, component)` labeling**, but does **not** require the round count to match
v0. Order-independent `atomicMin` converges in fewer rounds than one-hop
sort-merge; min-label has a unique fixpoint, so the final answer is the same.
For TC and SG, both the tuple set *and* the iteration count must match.

## 8. Data model

- Node IDs are **`int32`**. No 64-bit IDs, no strings, no attributes.
- Relations are **two-column** only.
- Input is a raw binary stream of `int32 (src, dst)` pairs; `data/binary_file_utils.py`
  converts to and from tab-separated text.
- The input is used as given: no deduplication, no symmetrization, no self-loop
  removal. See limitation 9.

## 9. GPUlog comparison caveats

- **Compute phase only.** GPUlog reports fixpoint time, not end-to-end. It is
  compared against our `compute` column, never against `total`.
- **TC and SG only.** GPUlog does not cover WCC, so the WCC comparison is against
  MNMGDatalog alone.
- **Known benign result-size divergence.** On the three road-network `.cedge`
  graphs (OL, TG, SF), GPUlog reports 0.02–0.09% more TC tuples than we do. These
  graphs contain self-edges `(v,v)`, and the two engines treat a self-derived path
  pair differently. Every other TC graph and all SG graphs agree to the tuple. A
  *large* or *new* divergence should be treated as a real error and investigated
  — see [`baselines.md`](baselines.md).
- **GPUlog is the one place we parse stdout.** It has no machine-readable output.
  All of our own binaries report through a `*_CSV` file.
- GPUlog is built "with its default toolchain" plus an injected `-std=c++17`; a
  loaded `nvhpc` module can silently shadow the CUDA version and change its
  numbers.

## 10. The incremental study is narrow

- **WCC only.** TC and SG have no incremental path here.
- **Insertion only.** These queries are monotone under edge insertion, which is
  exactly why a batch can be absorbed by continuing from the current answer.
  **Deletions are not supported** and would require a different algorithm.
- The base/insertion split is synthetic: each graph is cut into the first `1-f`
  and last `f` of its edge list.

## 11. Statistical rigor of the measurements

- Numbers are the **median of 3 timed runs** after one warm-up, on **one node**.
- No error bars, no confidence intervals, no cross-node variance study.
- `make benchmark` runs with `*_NO_OUTPUT=1`: the device→host transfer is still
  timed as `D2H`, but no multi-GB result file is written, so `fileio` covers the
  input read only. Pass `BENCH_KEEP_OUTPUT=1` for a run that also writes results,
  in which case `fileio` includes the write for every version.
- Peak memory is what the process reports, not a profiler measurement.

## 12. Portability

Tested only on the environment recorded in
[`environment.md`](environment.md): A100 `sm_80`,
CUDA 12.9.1, Linux, AMD EPYC 7532. `GPU_ARCH=native` and `sm_90` are expected to
work but are not part of the published results. The shell harness assumes
**bash** and GNU coreutils.
