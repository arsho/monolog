<div align="center">

# monolog

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

[Queries](#queries) -
[Versions](#versions) -
[Build](#build) -
[Documentation](#documentation) -
[Contribute](#contribute) -
[License](#license-and-authors) -
[References](#references) -
[Citation](#citation)

</div>

## Queries

| Query | Directory | Rule |
|-------|-----------|------|
| **Transitive Closure** | [`tc_benchmark/`](tc_benchmark/) | `path(a,c) :- path(a,b), edge(b,c)` |
| **Same Generation** | [`sg_benchmark/`](sg_benchmark/) | `sg(x,y) :- edge(p,x), edge(p,y), x≠y` ; `sg(x,y) :- edge(a,x), sg(a,b), edge(b,y)` |
| **Weakly Connected Components** | [`cc_benchmark/`](cc_benchmark/) | `cc(x,x) :- edge(x,_)` ; `cc(y,c) :- cc(x,c), edge(x,y)` (keep min `c`) |

## Versions

Each query is implemented four times. All four produce identical results,
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

Requires CUDA ≥ 12.4 (`v3` uses conditional graph nodes) and an NVIDIA GPU.

```bash
source environment/modules.sh     # module load cuda/12.9.1; GPU_ARCH=sm_80
bash scripts/check_env.sh

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

Pull requests are welcome — documentation, bug fixes, new datasets, new queries.
Open an issue first for anything substantial so we can agree on the approach.
For questions or bug reports, post on the
[issue tracker](https://github.com/arsho/monolog/issues) or start a thread on
[GitHub Discussions](https://github.com/arsho/monolog/discussions).

## License and authors

Distributed under the terms in [LICENSE](LICENSE). Contributors are listed in
[AUTHORS](AUTHORS).

## References

The two GPU Datalog engines monolog is compared against. **MNMGDatalog** supplies
the reference algorithm, ported here as each benchmark's `v0_reference/`.
**GPUlog** is an external baseline, pinned and run by `make gpulog`.

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

| Engine | Source |
|--------|--------|
| MNMGDatalog | <https://github.com/harp-lab/MNMGDatalog> |
| GPUlog (gdlog) | <https://github.com/harp-lab/gdlog> |

## Citation

If you use monolog in your work, please cite:

```
@inproceedings{shovon2026accelerating,
  title={Accelerating GPU Datalog with Kernel Fusion},
  author={Shovon, Ahmedur Rahman and Pereira, Romain and Sun, Yihao and Saif, Farhan and Kumar, Sidharth and Perarnau, Swann},
  booktitle={2026 IEEE/ACM 16th Workshop on Irregular Applications: Architectures and Algorithms (IA3)},
  year={2026},
  organization={IEEE}
}
```
