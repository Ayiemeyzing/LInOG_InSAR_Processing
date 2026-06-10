# LInOG Shared ISCE2 Environment Standard

All LInOG stripmapStack processing on `felix` must use the shared canonical environment:

`/eggraid/miniconda3/envs/linog_isce2`

## Shell helpers

Users should have the following commands available:

- `linog_isce2` — activate and verify the shared environment
- `linog_envinfo` — print current environment provenance
- `linog_off` — deactivate and clear LInOG environment variables

## Required usage

Before running any manual or batch LInOG ISCE2 pipeline:

```bash
linog_isce2
```

To verify active tools:

```bash
linog_envinfo
```

## Policy

Do not run production stripmapStack processing from personal conda environments such as `~/.conda/envs/isce2`.

Do not manually mix `PYTHONPATH`, `ISCE_HOME`, or `PATH` values from different ISCE2 installs.

All production scripts should assume and/or enforce the use of `linog_isce2`.