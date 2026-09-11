# data/

The 13 graphs used by the paper, plus a 10-edge smoke test. Committed so the
artifact reproduces offline with no downloads.

Full table (edge counts, which query uses which graph, checksums, capacity
sizing): [`../docs/datasets.md`](../docs/datasets.md).

## Format

Raw binary stream of `int32` `(src, dst)` pairs — 8 bytes per edge, no header,
native endianness. Edge count is `filesize / 8`.

Some graphs also ship a `.txt` twin (one `src<TAB>dst` per line). GPUlog reads
text, so `tests/gpulog_compare.sh` generates a missing `.txt` on demand.

## Converting

```bash
python3 binary_file_utils.py bin_to_txt data_7035.bin data_7035.txt
python3 binary_file_utils.py txt_to_bin data_7035.txt data_7035.bin
```

Synthetic graphs for smoke tests: `python3 generate_data.py`.

## Verifying

```bash
shasum -a 256 -c SHA256SUMS
```

## Notes

- Benchmarks find this directory automatically as
  `DATA_DIR=${DATA_DIR:-<benchmark>/../data}`. Override with `DATA_DIR=/path`.
- Input is consumed **as given**: no deduplication, no symmetrization, no
  self-loop removal. This is why GPUlog's TC counts differ slightly on the three
  `.cedge` road networks — see
  [`../docs/baselines.md`](../docs/baselines.md#validating-a-gpulog-run-result-size-cross-check).
- Result relations (`*_tc.bin`, `*_sg.bin`, `*_cc.bin`) are written here when a
  run is not in `*_NO_OUTPUT=1` mode. They can reach ~17 GB and are gitignored;
  clear them with `make clean-output` from any benchmark directory.
- Graphs originate from SNAP and the SuiteSparse Matrix Collection, converted to
  binary. Original terms apply.
