# monolog

Single-GPU Datalog engine that evaluates a recursive query as one fused,
device-resident kernel instead of a chain of relational-algebra operators.

`monolog` implements three recursive graph applications — transitive closure,
same generation, and weakly connected components — four different ways each, so
the cost of *how* a fixpoint is executed can be measured in isolation. All four
versions produce identical results, verified tuple for tuple.

```{toctree}
:maxdepth: 2
:caption: Getting started

quickstart
environment
datasets
jlse
```

```{toctree}
:maxdepth: 2
:caption: Reference

reproducibility
baselines
figure-map
limitations
```

## Applications

| Application | Directory | Rule |
|-------------|-----------|------|
| Transitive Closure | `tc_benchmark/` | `path(a,c) :- path(a,b), edge(b,c)` |
| Same Generation | `sg_benchmark/` | `sg(x,y) :- edge(p,x), edge(p,y), x≠y` ; `sg(x,y) :- edge(a,x), sg(a,b), edge(b,y)` |
| Weakly Connected Components | `cc_benchmark/` | `cc(x,x) :- edge(x,_)` ; `cc(y,c) :- cc(x,c), edge(x,y)` (keep min `c`) |

## The four versions

| Version | Name | What changes |
|---------|------|--------------|
| `v0` | MNMGDatalog (sort-merge) | Materialized relational algebra: Thrust `sort`/`unique`/`set_difference`/`merge`, per-iteration allocation. Reference. |
| `v1` | fused operators (host loop) | The operator chain fused into one kernel over pre-allocated buffers. Host `while` loop. |
| `v2` | + CUDA Graph (CPU condition) | One iteration captured into a CUDA graph and replayed; host checks termination. |
| `v3` | + Conditional CUDA Graph (GPU condition) | The whole fixpoint as a conditional `WHILE` node — one launch, convergence tested on device. |

`v0 → v1` is an algorithm change; `v1 → v2 → v3` are execution-strategy changes
over an identical kernel sequence.

## Where to start

- New here — {doc}`quickstart`
- On an ALCF JLSE node — {doc}`jlse`
- Reproducing the paper — {doc}`reproducibility`
- What this does *not* do — {doc}`limitations`

## Indices

- {ref}`genindex`
- {ref}`search`
