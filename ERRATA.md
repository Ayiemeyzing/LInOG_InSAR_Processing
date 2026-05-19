# ERRATA — LInOG InSAR Processing Manual

**Document:** `README.md`  
**Manual version:** 2.2  
**Repository:** `Ayiemeyzing/LInOG_InSAR_Processing`  
**Audited:** 2026-05-19  
**Status:** Critical script issues identified, corrected, and documented. README updated to use reusable Path/Frame variables and user-oriented wording.

---

## 1. Summary

This repository contains:

- a revised and parameterized `README.md`
- corrected operational scripts under `scripts/`
- documented assumptions for felix/NIGS-specific infrastructure
- cross-check notes between the manual and the uploaded scripts

The manual was updated to:

- use **users** instead of **students**
- support reusable run variables:
  - `PATH_NUM`
  - `FRAME_NUM`
  - `PADDED_PATH`
  - `PADDED_FRAME`
  - `FRAME_TAG`
  - `BASE_DIR`
  - `WORK_DIR`
- reduce hardcoded frame-specific commands in the workflow
- preserve frame-specific examples only where needed

---

## 2. Critical Bugs Fixed

| ID | Severity | File | Issue | Resolution |
|----|----------|------|-------|------------|
| B1 | Critical | `scripts/linog_save_insar_images.py` | `mag_norm[p_high == p_low] = 0` used a scalar boolean as an array index and could raise `IndexError` | Replaced with an early return when `p_high == p_low` |
| B2 | Critical | `scripts/linog_fbs_processor.sh` | `mintpy.load.metaFile = .../reference/IW1.xml` was Sentinel-1 TOPS-specific and invalid for ALOS stripmap processing | Replaced with `reference/*.xml` wildcard |
| B3 | Critical | `scripts/linog_fbs_processor.sh` | MintPy config used `filt_fine.unw`, `filt_fine.cor`, and `filt_fine.unw.conncomp`, which are topsStack naming conventions rather than stripmapStack date-pair naming | Replaced with wildcard stripmap-compatible patterns: `filt_*.unw`, `filt_*.cor`, `filt_*.unw.conncomp` |
| B4 | Critical | `scripts/linog_fbs_processor.sh` | Phase 4.5 printed incorrect script names (`save_insar_images.py`, `create_grid.py`) instead of repository filenames with the `linog_` prefix | Replaced with `linog_save_insar_images.py` and `linog_create_grid.py` |

---

## 3. Minor Bugs Fixed

| ID | Severity | File | Issue | Resolution |
|----|----------|------|-------|------------|
| B5 | Minor | `scripts/linog_save_insar_images.py` | Usage string printed `save_insar_images.py` instead of the real filename | Updated usage string to `linog_save_insar_images.py` |
| B6 | Minor | `scripts/linog_gen_interactive_kmz.py` | `matplotlib.pyplot` was imported inside a repeatedly called helper function | Moved import to module scope |
| B7 | Minor | `scripts/linog_gen_interactive_kmz.py` | Used deprecated `plt.cm.jet` access pattern | Replaced with `matplotlib.colormaps['jet']` |

---

## 4. README v2.2 Improvements

These are documentation improvements rather than bug fixes.

| ID | Type | Area | Improvement |
|----|------|------|-------------|
| D1 | Documentation | Global wording | Replaced **students** with **users** throughout the manual |
| D2 | Documentation | Run configuration | Added reusable variables for Path/Frame runs |
| D3 | Documentation | Phase 0 onward | Converted hardcoded `p448/f0310` style examples into variable-based commands where appropriate |
| D4 | Documentation | Local and felix flow | Clarified variable setup for both `[LOCAL]` and `[FELIX]` environments |
| D5 | Documentation | Output naming | Standardized references to `${FRAME_TAG}` and related run variables |

---

## 5. Manual ↔ Script Cross-Check

### 5.1 Confirmed Consistent

| Area | Result |
|------|--------|
| `linog_create_grid.py` usage in manual | Consistent |
| `linog_gen_interactive_kmz.py --correction demErr / demErr_ramp` | Consistent |
| Deliverable naming in Phase 6 and Section 15 | Consistent with script output naming |
| `CORRECTION_MAP` file mapping in KMZ script | Consistent with documented MintPy outputs |
| `linog_` script naming convention | Now consistent across manual and scripts |

### 5.2 Noted Operational Distinctions

| Area | Note |
|------|------|
| Reference date `20091111` | Valid as a known good example for specific frames such as 0310, but must be reviewed per frame |
| `linog_save_insar_images.py` | Operates on `.int` files in the current directory, so it does not directly need Path/Frame arguments |
| `linog_create_grid.py` and `linog_gen_interactive_kmz.py` | Correctly support `--path` and `--frame` arguments |

---

## 6. Verified Correct Items

The following items were reviewed and did **not** require code changes:

- `scripts/linog_create_grid.py` page layout logic
- `scripts/linog_create_grid.py` date extraction and image pairing behavior
- `scripts/linog_gen_interactive_kmz.py` `CORRECTION_MAP`
- `scripts/linog_fbs_processor.sh` Phase 6 suffix logic for `demErr` and `demErr_ramp`
- MintPy `view.py`, `save_gdal.py`, and `save_kmz.py` command usage
- `stackStripMap.py` parameter pattern for FBS stripmap processing
- use of `geo_timeseries_ramp_demErr.h5` for `demErr_ramp`
- Python 3.12 pinning in the environment setup for conda-forge ISCE2

---

## 7. External Dependency / Platform Warnings

These are not direct script bugs, but users should be aware of them.

| ID | Area | Warning |
|----|------|---------|
| W1 | DEM download | `http://step.esa.int/auxdata/dem/SRTMGL1/` may experience intermittent downtime |
| W2 | Apple Silicon | ISCE2 is not officially distributed for `osx-arm64` via conda-forge |
| W3 | Conda solving | Some environments may solve slowly; `mamba` may be needed |
| W4 | Google Charts in KMZ | Interactive chart behavior depends on Google Earth and external chart loader support |

---

## 8. Felix / Infrastructure Assumptions

These steps are intentionally preserved but should be verified in the actual environment.

| ID | Area | Assumption |
|----|------|------------|
| F1 | Server paths | `/eggraid/...` is specific to felix/NIGS storage layout |
| F2 | Internal utilities | `find_alos.sh` is locally maintained and not publicly verifiable here |
| F3 | Internal utilities | `run_unpack_all_cli.py` is locally maintained and not publicly verifiable here |
| F4 | Internal utilities | `poststep04_cleanup.py` is locally maintained and not publicly verifiable here |
| F5 | Shared tool location | `/eggraid/sbin` contents may differ across deployments |
| F6 | Reference metadata contents | Exact files under `reference/*.xml` may vary by processor version and product type |

---

## 9. Recommended User Checks Before Running

Before processing a new frame, users should verify:

1. `PATH_NUM` is exactly 3 digits
2. `FRAME_NUM` is exactly 4 digits
3. `BASE_DIR` matches the actual environment:
   - felix: `/eggraid/home/$USER/projects/linog/insar`
   - local: `$HOME/LInOG/insar`
4. `load_isce` correctly activates the expected environment
5. `reference/*.xml` and interferogram outputs match the processor’s actual generated filenames
6. the delivery folder name matches `${FRAME_TAG}` exactly

---

## 10. Current Repository Layout

Expected structure:

```text
LInOG_InSAR_Processing/
├── README.md
├── ERRATA.md
└── scripts/
    ├── check_preflight.sh
    ├── linog_save_insar_images.py
    ├── linog_create_grid.py
    ├── linog_gen_interactive_kmz.py
    └── linog_fbs_processor.sh
```

---

## 11. Final Status

### Code status
- Critical issues: **fixed**
- Minor issues: **fixed**
- Remaining concerns: environment-specific verification only

### Documentation status
- README updated to version **2.2**
- manual now supports reusable Path/Frame configuration
- wording updated from **students** to **users**

---

*End of ERRATA*
