# Datasets

All 13 graphs used by the paper are committed in [`data/`](https://github.com/arsho/monolog/tree/main/data), so the
artifact reproduces offline with no downloads. They are carried over unmodified
from the MNMGDatalog repository, which is the provenance of record for the
conversions.

## Format

A dataset is a **raw binary stream of `int32` `(src, dst)` pairs** — 8 bytes per
edge, no header, native endianness. Edge count is therefore `filesize / 8`.

Some graphs also ship a `.txt` twin: the same edges, one `src<TAB>dst` per line.
GPUlog reads text, so `tests/gpulog_compare.sh` generates a missing `.txt` on
demand via `tests/bin_to_txt.py`.

Convert either way with the vendored helper:

```bash
python3 data/binary_file_utils.py bin_to_txt data/data_7035.bin  data/data_7035.txt
python3 data/binary_file_utils.py txt_to_bin data/data_7035.txt  data/data_7035.bin
```

Synthetic graphs for smoke tests: `python3 data/generate_data.py`.

The input is consumed **as given** — no deduplication, no symmetrization, no
self-loop removal. This matters for the `.cedge` road networks; see
[`baselines.md`](baselines.md#validating-a-gpulog-run-result-size-cross-check).

## The graphs

`|E|` is the edge count in the `.bin`. Checksums are the first 16 hex digits of
SHA-256; the full list is in [`data/SHA256SUMS`](https://github.com/arsho/monolog/blob/main/data/SHA256SUMS).

### Transitive closure (`tc_benchmark`)

| File | Short name | \|E\| | Source | # TC | Iters | sha256 |
|------|-----------|------:|--------|-----:|------:|--------|
| `data_7035.bin` | OL.cedge | 7,035 | SuiteSparse (road network) | 146,120 | 64 | `a4220698a96f77cb` |
| `data_23874.bin` | TG.cedge | 23,874 | SuiteSparse (road network) | 481,121 | 58 | `92a3ef6c8a927e88` |
| `data_223001.bin` | SF.cedge | 223,001 | SuiteSparse (road network) | 80,498,014 | 287 | `0762714e98a65461` |
| `data_163734.bin` | fe_body | 163,734 | SuiteSparse | 156,120,489 | 188 | `66de6c57f5c2d232` |
| `data_147892.bin` | p2p-Gnutella31 | 147,892 | SNAP | 884,179,859 | 31 | `404fe43b49543be1` |
| `vsp_finan512_scagr7-2c_rlfddd.bin` | vsp_finan | 552,020 | SuiteSparse | 910,070,918 | 520 | `7dde55b251ddd3d0` |

### Same generation (`sg_benchmark`)

| File | Short name | \|E\| | Source | sha256 |
|------|-----------|------:|--------|--------|
| `data_51971.bin` | CA-HepTh | 51,971 | SNAP | `600a44fb66dbd333` |
| `data_49152.bin` | fe_sphere | 49,152 | SuiteSparse | `f2a4357d27501ba7` |
| `data_214078.bin` | loc-Brightkite | 214,078 | SNAP | `1d8d707f685b839c` |
| `data_163734.bin` | fe_body | 163,734 | SuiteSparse | `66de6c57f5c2d232` |

### Weakly connected components + streaming (`cc_benchmark`)

| File | Short name | \|E\| | Source | sha256 |
|------|-----------|------:|--------|--------|
| `data_51971.bin` | CA-HepTh | 51,971 | SNAP | `600a44fb66dbd333` |
| `WikiTalk.bin` | WikiTalk | 5,021,410 | SNAP | `fdfe85028d660e32` |
| `web-Google.bin` | web-Google | 5,105,039 | SNAP | `a42f527c255741d8` |
| `as-skitter.bin` | as-skitter | 11,095,298 | SNAP | `286160e06c681443` |
| `roadNet-CA.bin` | roadNet-CA | 5,533,214 | SNAP | `01ee9522ab027dcc` |

### Smoke test

| File | \|E\| | Purpose | sha256 |
|------|------:|---------|--------|
| `data_10.bin` | 10 | 10-edge toy graph; the Makefile default `DATA` for `make run0..run3` | `7e875d401af26317` |

## Verifying integrity

```bash
cd data && shasum -a 256 -c SHA256SUMS
```

## Capacity sizing

For TC and SG the result hash set is allocated once as
`next_pow2(n_edges × capacity_mult)` and must hold **≥ ~2× the result size**.
`tests/benchmark.sh` maps each dataset to a tuned `capacity_mult`:

| Dataset | Short name | # TC | `ds_mult` | Set slots | Set size |
|---------|-----------|-----:|----------:|----------:|---------:|
| `data_7035` | OL.cedge | 146 K | 64 | 512 K | ~4 MB |
| `data_23874` | TG.cedge | 481 K | 64 | 2 M | ~16 MB |
| `data_223001` | SF.cedge | 80 M | 1024 | 256 M | 2 GB |
| `data_163734` | fe_body | 156 M | 2048 | 512 M | 4 GB |
| `data_147892` | p2p-Gnutella31 | 884 M | 12288 | 2.1 B | 17 GB |
| `data_409593` | fe_ocean (opt-in) | 1.67 B | 8192 | 4.3 B | 34 GB |

A graph not in that table falls back to the CLI `MULT` and may need tuning; an
undersized table fails fast rather than rehashing. See
[`limitations.md`](limitations.md#2-fixed-capacity-no-grow-and-rehash).

## Using your own graph

```bash
python3 data/binary_file_utils.py txt_to_bin mygraph.txt data/mygraph.bin
cd tc_benchmark && make benchmark DS="mygraph.bin" MULT=<multiplier>
```

Every target accepts `DS="a.bin b.bin"` to override the dataset list and
`DATA_DIR=/path/to/data` to relocate the input directory.

## Attribution

Graphs originate from the **SNAP** collection (Leskovec & Krevl, *SNAP Datasets:
Stanford Large Network Dataset Collection*) and the **SuiteSparse Matrix
Collection** (Davis & Hu). They are redistributed here in converted binary form
solely to make the artifact self-contained; original terms apply.
