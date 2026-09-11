# Compared engines

The paper compares against **two GPU Datalog engines**. This document records
exactly which version of each was used, how it is provided in this repository,
and how to validate that a re-run of the comparison is trustworthy.

| Engine | Role | Provided as |
|--------|------|-------------|
| **MNMGDatalog** | Multi-node multi-GPU Datalog engine. Its per-round materialized relational algebra is the performance **reference**. | Vendored — each benchmark's `v0_reference/` |
| **GPUlog** (gdlog) | State-of-the-art single-GPU Datalog engine built on HISA range-indexed relations (ASPLOS'25). | Pinned external checkout in `third_party/gdlog` |

---

## MNMGDatalog (vendored as `v0_reference/`)

`v0` is a faithful **single-GPU port** of the MNMGDatalog algorithm, not a
wrapper around the original binary. It reproduces the engine's per-round
behavior exactly:

- materialized relational algebra: `get_join` ⋈ → `sort` + `unique` (dedup) →
  `set_difference` (∖) → `merge` (∪),
- per-iteration `cudaMalloc` / `cudaFree` for the intermediates,
- host `while` loop with a CPU-side convergence test (relation stopped growing).

Porting it into the repository is what makes the comparison fair: v0 and v1–v3
read the same input through the same IO path, are timed with the same phase
model, and write results in the same format, so the only difference measured is
the fixpoint strategy itself.

**Validation.** `v0`'s absolute timings match the source engine's published
regime — `fe_body` = 5.1 s, `vsp_finan` = 83.1 s — which is the expected cost of
discrete sort-merge relational algebra on those graphs.

- Upstream: <https://github.com/harp-lab/MNMGDatalog>
- Source files ported: `tc.cu`, `sg.cu`, `wcc.cu`

## GPUlog / gdlog

- Upstream: <https://github.com/harp-lab/gdlog>
- **Pinned commit: `65a6ee960ced8d04bc725ccdfa68f004f8479226`** (2024-05-22)
- License: MIT (HARP Lab)
- Coverage: **TC and SG only** — GPUlog does not implement WCC.
- Reports **fixpoint compute time only**, so it is compared against our
  `compute` column, never against `total`.

### Getting it

Not vendored, to avoid redistributing third-party code. Either:

```bash
bash scripts/setup_gdlog.sh          # clones + pins into third_party/gdlog
```

or, once this repository is under git, as a submodule:

```bash
git submodule add https://github.com/harp-lab/gdlog third_party/gdlog
git -C third_party/gdlog checkout 65a6ee960ced8d04bc725ccdfa68f004f8479226
git add .gitmodules third_party/gdlog && git commit -m "Pin GPUlog baseline"
```

`tests/gpulog_compare.sh` probes, in order: `$GDLOG_DIR`,
`../third_party/gdlog`, `../../gdlog`, `../../../gdlog`, `~/gdlog`. An existing
checkout elsewhere works with `GDLOG_DIR=/path/to/gdlog`.

### Running the comparison

```bash
cd tc_benchmark && make GPU_ARCH=sm_80 gpulog REPEATS=3    # -> results/gpulog_<ts>.csv
cd sg_benchmark && make GPU_ARCH=sm_80 gpulog REPEATS=3
```

The harness feeds GPUlog the **identical graphs**, converting each `.bin` to the
tab-separated text it expects via `tests/bin_to_txt.py` when a `.txt` is not
already present. It runs the `TC`/`SG` binary with eager buffer management
(`EBM=0`, its best mode) and records the reported result count and time.

### Two build gotchas (both hit on JLSE)

1. **C++ standard.** gdlog's CMake sets no C++ standard, and modern CCCL/CUB
   (CUDA 12.4+/13.x) hard-errors with *"CUB requires at least C++17."* The
   harness injects `-DCMAKE_CXX_STANDARD=17 -DCMAKE_CUDA_STANDARD=17`
   (plus `CCCL_IGNORE_DEPRECATED_CPP_DIALECT`) at configure time **without
   modifying any gdlog file**. Building gdlog by hand requires the same flags.

2. **Stale build directory.** If a previous configure cached the wrong settings,
   the new flags will not apply:

   ```bash
   rm -rf third_party/gdlog/build
   cd tc_benchmark && make GPU_ARCH=sm_80 gpulog
   ```

3. **Toolchain parity.** A loaded `nvhpc` module can shadow `cuda/12.9.1` and
   pull CUDA 13.0 headers into the gdlog build. Confirm with `module list`. For
   exact parity, build gdlog under the same CUDA the benchmarks use.

### Validating a GPUlog run: result-size cross-check

A GPUlog run is only trustworthy if its **result size** matches ours on the same
graph — identical query, identical input. Compare `gpulog_tc` / `gpulog_sg` in
the GPUlog CSV against the `tc` / `sg` column of our benchmark CSV.

| Query | Matches exactly | Differs (and by how much) |
|-------|-----------------|---------------------------|
| **SG** | CA-HepTh, fe_sphere, loc-Brightkite, fe_body — **all match** | none |
| **TC** | fe_body, p2p-Gnutella31, vsp_finan — **match** | OL (+126), TG (+2942), SF (+12948) |

The three differing TC graphs are **exactly the road-network `.cedge` graphs**,
and the gap is 0.02–0.09%. These graphs contain self-edges `(v,v)`, and the two
engines treat a self-derived path pair differently: our hash-set closure keeps
`(v,v)` once, GPUlog's semi-naïve/HISA evaluation handles the self-loop
differently. This is a **benign engine-semantics difference, not a broken run**;
the timings remain a fair compute-phase comparison of the same closure on the
same graph.

**If you re-run and see a large or new size divergence, treat it as a real
error** — bad conversion, truncated `.txt`, or the wrong dataset — and
investigate before reporting timings.

### Why we parse GPUlog's stdout

GPUlog is a third-party binary with no machine-readable output, so
`tests/gpulog_compare.sh` greps its stdout for `TC time:` / `sg time:` and
`Path counts` / `sg counts`. **This is the only place in the repository where a
binary's stdout is parsed.** All of our own binaries write a single 15-column row
to the file named by `TC_CSV` / `SG_CSV` / `CC_CSV`, and the harness reads that
file — never stdout.

## Engines discussed but not re-run here

The paper situates the work against `GPUjoin`, `INLjoin`, `Bjoin`, `Powerlog`,
RedFox, RaSQL, RecStep, Soufflé, and RDFox. Those are cited from their published
numbers and are **not** part of this artifact; only MNMGDatalog and GPUlog are
executed on our hardware, on our graphs, for this comparison.

## References

```
@inproceedings{shovon2025mnmgdatalog,
  title={Multi-Node Multi-GPU Datalog},
  author={Shovon, Ahmedur Rahman and Sun, Yihao and Micinski, Kristopher and Gilray, Thomas and Kumar, Sidharth},
  booktitle={Proceedings of the 2025 International Conference on Supercomputing (ICS '25)},
  year={2025},
  publisher={ACM},
  doi={10.1145/3721145.3730431}
}

@inproceedings{sun2025optimizing,
  title={Optimizing Datalog for the GPU},
  author={Sun, Yihao and Shovon, Ahmedur Rahman and Gilray, Thomas and Kumar, Sidharth and Micinski, Kristopher},
  booktitle={Proceedings of the 30th ACM International Conference on Architectural Support for Programming Languages and Operating Systems (ASPLOS '25)},
  pages={762--776},
  year={2025},
  publisher={ACM},
  doi={10.1145/3669940.3707274}
}
```
