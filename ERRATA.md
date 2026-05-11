[ERRATA.md](https://github.com/user-attachments/files/27580698/ERRATA.md)
# ERRATA — LInOG InSAR Processing Manual v2.1

**Document:** `LInOG_InSAR_Processing_Manual_v2.1.md`  
**Audited:** 2026-05-11  
**Auditor:** Copilot automated cross-audit (manual ↔ scripts)  
**Status:** All critical and minor bugs listed below are fixed in the scripts under `scripts/`.

---

## Change Log

| ID  | Severity | File | Description | Status |
|-----|----------|------|-------------|--------|
| B1  | 🔴 Critical | `linog_save_insar_images.py` | `stretch_magnitude()`: scalar bool used as array index → `IndexError` at runtime | ✅ Fixed |
| B2  | 🔴 Critical | `linog_fbs_processor.sh` | `mintpy.load.metaFile` set to `IW1.xml` (Sentinel-1/TOPS-specific) — ALOS FBS uses stripmapStack, no IW subswath XML | ✅ Fixed |
| B3  | 🔴 Critical | `linog_fbs_processor.sh` | `filt_fine.unw / .cor / .unw.conncomp` are topsStack naming conventions — stripmapStack uses date-pair filenames | ✅ Fixed |
| B4  | 🔴 Critical | `linog_fbs_processor.sh` | Phase 4.5 echo block prints `save_insar_images.py` and `create_grid.py` — missing `linog_` prefix; students copy-pasting get file-not-found | ✅ Fixed |
| B5  | 🟡 Minor   | `linog_save_insar_images.py` | `__main__` usage string missing `linog_` prefix — inconsistent with actual filename | ✅ Fixed |
| B6  | 🟡 Minor   | `linog_gen_interactive_kmz.py` | `import matplotlib.pyplot as plt` inside `v2c()` — called once per valid pixel; poor practice, adds unnecessary overhead per call | ✅ Fixed |
| B7  | 🟡 Minor   | `linog_gen_interactive_kmz.py` | `plt.cm.jet` deprecated since matplotlib 3.7 — raises `MatplotlibDeprecationWarning`, will break in future versions | ✅ Fixed |

---

## Verified Correct (No Changes Needed)

- `linog_create_grid.py` — grid logic, column ratios, page layout, date-pair extraction all correct
- `CORRECTION_MAP` in `linog_gen_interactive_kmz.py` — `ramp_demErr` filename order matches MintPy output convention
- Phase 6 SUFFIX logic in `linog_fbs_processor.sh` — produces all 16 expected deliverable filenames correctly
- `view.py`, `save_gdal.py`, `save_kmz.py` CLI calls — valid MintPy commands
- `stackStripMap.py` parameters (Phase 3) — correct flags for FBS stripmapStack
- MintPy config `azAngleFile` + `incAngleFile` both pointing to `los.rdr` — correct, ISCE2 packs both bands in one file
- Interactive KMZ `ts.shape[1]` / `ts.shape[2]` indexing — correct for MintPy timeseries shape `(n_dates, rows, cols)`
- Python 3.12 in conda env — **confirmed supported** by conda-forge ISCE2 (tested up to 3.13 as of Sep 2025)
- `python=3.12` pin in manual — **correct and consistent** with felix environment

---

## External Dependency Warnings

| ID | Location | Warning |
|----|----------|---------|
| W1 | §7 / Phase 2 | `dem.py` URL `http://step.esa.int/auxdata/dem/SRTMGL1/` — ESA SNAP auxiliary server has intermittent downtime. Fallback: NASA EarthData SRTM via `dem.py -u https://e4ftl01.cr.usgs.gov/MEASURES/SRTMGL1.003/2000.02.11/` |
| W2 | ~~§2.1.2~~ | ~~`python=3.12` may not be available~~ — **RETRACTED**. Python 3.12 is confirmed supported on conda-forge ISCE2 as of Sep 2025 |

---

## Felix/Server Assumptions (Cannot Verify Without Server Access)

These steps depend on internal NIGS/LInOG server configuration. They are documented as-is; flag for verification when running on a new server.

| Flag | Location | Assumption |
|------|----------|------------|
| F1 | All phases | `/eggraid/` mount path — server-specific, may differ on new hardware |
| F2 | Phase 1 | `find_alos.sh` — internal script, not in any public repository |
| F3 | Phase 1 | `run_unpack_all_cli.py` — internal script |
| F4 | Phase 4 | `poststep04_cleanup.py` — internal script |
| F5 | Phase 3 | Reference date `20091111` confirmed optimal for Frame 0310 only; other frames require independent baseline plot review |
| F6 | Phase 5 | Exact XML filename inside `reference/` depends on stripmapStack version and ALOS product type; wildcard `*.xml` used as fix for B2 |

---

## Manual ↔ Script Cross-Check Summary

| Manual Section | Script | Result |
|----------------|--------|--------|
| §10.2 — `linog_save_insar_images.py` | `linog_fbs_processor.sh` Phase 4.5 | ⚠️ Discrepancy — script echoed wrong name (Bug B4, fixed) |
| §10.2 — `linog_create_grid.py` | `linog_fbs_processor.sh` Phase 4.5 | ⚠️ Discrepancy — script echoed wrong name (Bug B4, fixed) |
| §11 — `geo_timeseries_ramp_demErr.h5` | `linog_gen_interactive_kmz.py` `CORRECTION_MAP` | ✅ Consistent |
| §12.4 — `--correction demErr / demErr_ramp` | `linog_gen_interactive_kmz.py` argparse | ✅ Consistent |
| §15 deliverables checklist filenames | `linog_fbs_processor.sh` Phase 6 output names | ✅ Consistent |

---

*End of ERRATA*
