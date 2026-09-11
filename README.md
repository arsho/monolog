<div align="center">

# Monolog

<p align="center">
  <a href="https://monolog.readthedocs.io/en/latest/">
  <img alt="Documentation" src="https://readthedocs.org/projects/monolog/badge/?version=latest">
  </a>
  <a href="https://opensource.org/licenses/BSD-3-Clause">
  <img alt="License" src="https://img.shields.io/badge/License-BSD_3--Clause-blue.svg">
  </a>
  <a href="https://developer.nvidia.com/cuda-downloads">
  <img alt="CUDA" src="https://img.shields.io/badge/CUDA-%E2%89%A512.4-76b900.svg">
  </a>
</p>

<p>
A single-GPU Datalog engine that runs a recursive query as one fused,
device-resident kernel instead of a chain of relational-algebra operators.
</p>

[Applications](#applications) -
[Versions](#versions) -
[Build](#build) -
[Documentation](#documentation) -
[Contribute](#contribute) -
[License](#license-and-authors) -
[References](#references) -
[Citation](#citation)

</div>

## Applications

| Application | Directory | Description |
|-------------|-----------|-------------|
| **Transitive Closure** | [`tc_benchmark/`](tc_benchmark/) | All-pairs reachability. Single-join recursion; the closure can reach a billion pairs. |
| **Same Generation** | [`sg_benchmark/`](sg_benchmark/) | Nodes at equal depth from a common ancestor. Two-hop, two-join recursion. |
| **Weakly Connected Components** | [`cc_benchmark/`](cc_benchmark/) | Component labeling by minimum node id. Also drives the streaming/incremental study. |

## Versions

Each application is implemented four times. All four produce identical results,
verified tuple for tuple by `make test`; they differ only in *how* the fixpoint
is executed.

| Version | Name | What changes |
|---------|------|--------------|
| **v0** | MNMGDatalog (sort-merge) | Materialized relational algebra with Thrust `sort`/`unique`/`set_difference`/`merge` and per-iteration allocation. Reference. |
| **v1** | fused operators (host loop) | The operator chain fused into one CUDA kernel over fixed pre-allocated buffers. Host `while` loop. |
| **v2** | + CUDA Graph (CPU condition) | One iteration captured into a CUDA graph and replayed; the host still checks the termination flag. |
| **v3** | + Conditional CUDA Graph (GPU condition) | The whole fixpoint as a conditional `WHILE` node — one `cudaGraphLaunch`, convergence tested on the device. |

`v0 → v1` is an algorithm change. `v1 → v2 → v3` are execution-strategy changes
over an identical kernel sequence.

## Build

Requires an NVIDIA GPU and CUDA ≥ 12.4 (`v3` uses conditional graph nodes).
Set `GPU_ARCH` for your device: `sm_80` for A100, `sm_90` for H100, or `native`.

```bash
bash scripts/check_env.sh         # nvcc version, arch, VRAM, datasets

cd tc_benchmark
make GPU_ARCH=sm_80 all           # build v0-v3
make test                         # correctness: v1-v3 tuples == v0
make benchmark REPEATS=3          # -> results/benchmark_<ts>.csv
make plot                         # -> results/charts/
```

## Documentation

Full documentation is at
[monolog.readthedocs.io](https://monolog.readthedocs.io/en/latest/).

## Contribute

Pull requests are welcome — documentation, bug fixes, new datasets, new
applications. Open an issue first for anything substantial so we can agree on
the approach. For questions or bug reports, post on the
[issue tracker](https://github.com/arsho/monolog/issues).

## License and authors

Distributed under the terms in [LICENSE](LICENSE). Contributors are listed in
[AUTHORS](AUTHORS).

## References

The GPU Datalog engines Monolog is compared against:

- [MNMGDatalog](https://github.com/harp-lab/MNMGDatalog) — [Multi-Node Multi-GPU Datalog](https://doi.org/10.1145/3721145.3730431), ICS '25.
- [GPUlog / gdlog](https://github.com/harp-lab/gdlog) — [Optimizing Datalog for the GPU](https://doi.org/10.1145/3669940.3707274), ASPLOS '25.

The CUDA features Monolog builds on:

- [CUDA Graphs](https://docs.nvidia.com/cuda/cuda-c-programming-guide/#cuda-graphs)
- [Conditional graph nodes](https://docs.nvidia.com/cuda/cuda-c-programming-guide/#conditional-graph-nodes)

The graph collections the datasets come from:

- [SNAP: Stanford Large Network Dataset Collection](https://snap.stanford.edu/data/)
- [SuiteSparse Matrix Collection](https://sparse.tamu.edu/)

## Citation

If you use Monolog, please cite:

```
@inproceedings{shovon2026accelerating,
  title={Accelerating GPU Datalog with Kernel Fusion},
  author={Shovon, Ahmedur Rahman and Pereira, Romain and Sun, Yihao and Saif, Farhan and Kumar, Sidharth and Perarnau, Swann},
  booktitle={2026 IEEE/ACM 16th Workshop on Irregular Applications: Architectures and Algorithms (IA3)},
  year={2026},
  organization={IEEE}
}
```
