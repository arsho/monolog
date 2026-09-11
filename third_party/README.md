# third_party/

Mount point for external baselines. **Nothing here is vendored** — third-party
code is fetched at a pinned commit rather than redistributed.

## gdlog (GPUlog)

| | |
|---|---|
| Upstream | <https://github.com/harp-lab/gdlog> |
| Pinned commit | `65a6ee960ced8d04bc725ccdfa68f004f8479226` (2024-05-22) |
| License | MIT (HARP Lab) |
| Needed for | `make gpulog` only — TC, SG and WCC run without it |

Fetch it:

```bash
bash scripts/setup_gdlog.sh
```

or, once this repository is under git, as a submodule:

```bash
git submodule add https://github.com/harp-lab/gdlog third_party/gdlog
git -C third_party/gdlog checkout 65a6ee960ced8d04bc725ccdfa68f004f8479226
```

An existing checkout elsewhere also works: `export GDLOG_DIR=/path/to/gdlog`.

Build gotchas, the result-size cross-check, and why GPUlog is the one binary
whose stdout we parse: [`../docs/baselines.md`](../docs/baselines.md).
