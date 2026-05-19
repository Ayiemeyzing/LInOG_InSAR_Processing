# ERRATA — LInOG InSAR Processing Manual

**Repository:** `Ayiemeyzing/LInOG_InSAR_Processing`  
**Current manual file:** `README.md`  
**Current manual version:** 2.2  
**Audit history preserved:** Yes  
**Last updated:** 2026-05-19

---

## 1. Current Status

This repository now contains:

- a revised `README.md` based on the original manual
- corrected scripts under `scripts/`
- preserved audit history from the earlier v2.1 review
- updated documentation for reusable Path/Frame processing

### Current state summary
- Critical script bugs found in the original audit: **fixed**
- Minor script bugs found in the original audit: **fixed**
- README wording updated from **students** to **users**
- README updated to support reusable variables:
  - `PATH_NUM`
  - `FRAME_NUM`
  - `PADDED_PATH`
  - `PADDED_FRAME`
  - `FRAME_TAG`
  - `BASE_DIR`
  - `WORK_DIR`

---

## 2. Active Corrections Reflected in This Repository

These fixes are already reflected in the current repository files.

| ID | Severity | File | Issue | Current Resolution |
|----|----------|------|-------|--------------------|
| B1 | Critical | `scripts/linog_save_insar_images.py` | Scalar boolean used as array index in `stretch_magnitude()` could raise `IndexError` | Fixed with early return when `p_high == p_low` |
| B2 | Critical | `scripts/linog_fbs_processor.sh` | `mintpy.load.metaFile = .../reference/IW1.xml` was Sentinel-1/TOPS-specific and invalid for ALOS stripmap processing | Replaced with `reference/*.xml` |
| B3 | Critical | `scripts/linog_fbs_processor.sh` | MintPy config used `filt_fine.*` naming conventions inconsistent with stripmapStack date-pair outputs | Replaced with `filt_*.unw`, `filt_*.cor`, and `filt_*.unw.conncomp` |
| B4 | Critical | `scripts/linog_fbs_processor.sh` | Phase 4.5 displayed wrong script names without the `linog_` prefix | Corrected printed commands |
| B5 | Minor | `scripts/linog_save_insar_images.py` | Usage string referenced wrong filename | Corrected |
| B6 | Minor | `scripts/linog_gen_interactive_kmz.py` | `matplotlib.pyplot` imported inside repeatedly used helper | Moved to module scope |
| B7 | Minor | `scripts/linog_gen_interactive_kmz.py` | Deprecated `plt.cm.jet` usage | Replaced with `matplotlib.colormaps['jet']` |

---

## 3. README v2.2 Documentation Changes

These are documentation improvements added after the original v2.1 audit.

| ID | Type | Area | Change |
|----|------|------|--------|
| D1 | Documentation | Global wording | Replaced **students** with **users** |
| D2 | Documentation | Run configuration | Added reusable run variables for Path/Frame processing |
| D3 | Documentation | Workflow steps | Replaced many hardcoded frame references with `${PATH_NUM}`, `${FRAME_NUM}`, `${FRAME_TAG}`, and `${WORK_DIR}` |
| D4 | Documentation | Environment setup | Clarified both `[LOCAL]` and `[FELIX]` variable setup |
| D5 | Documentation | Naming consistency | Standardized use of `linog_` script names and `${FRAME_TAG}` output references |

---

## 4. Confirmed Correct Items

The following were reviewed and did not require code changes:

- `scripts/linog_create_grid.py` page layout logic
- `scripts/linog_create_grid.py` date extraction and pairing behavior
- `scripts/linog_gen_interactive_kmz.py` `CORRECTION_MAP`
- `scripts/linog_fbs_processor.sh` Phase 6 suffix logic for `demErr` and `demErr_ramp`
- MintPy CLI usage for `view.py`, `save_gdal.py`, and `save_kmz.py`
- `stackStripMap.py` flag pattern for FBS stripmap processing
- use of `geo_timeseries_ramp_demErr.h5` for `demErr_ramp`
- Python 3.12 pinning for conda-forge ISCE2

---

## 5. External Dependency and Platform Warnings

These are not repository code bugs, but users should be aware of them.

| ID | Area | Warning |
|----|------|---------|
| W1 | DEM download | `http://step.esa.int/auxdata/dem/SRTMGL1/` may have intermittent downtime |
| W2 | Apple Silicon | ISCE2 is not officially distributed for `osx-arm64` via conda-forge |
| W3 | Conda solving | Some systems may need `mamba` due to slow solver performance |
| W4 | Interactive KMZ | Google Charts behavior depends on Google Earth support for embedded HTML/JS and remote assets |

---

## 6. Felix / Infrastructure Assumptions

These steps are environment-specific and should be verified on the actual deployment.

| ID | Area | Assumption |
|----|------|------------|
| F1 | Storage layout | `/eggraid/...` paths are specific to felix/NIGS |
| F2 | Internal utility | `find_alos.sh` is internal and not publicly verifiable here |
| F3 | Internal utility | `run_unpack_all_cli.py` is internal and not publicly verifiable here |
| F4 | Internal utility | `poststep04_cleanup.py` is internal and not publicly verifiable here |
| F5 | Shared scripts | `/eggraid/sbin` contents may vary by deployment |
| F6 | Reference metadata | Exact files matched by `reference/*.xml` may vary by processor version |

---

## 7. Recommended Checks Before Running a New Frame

Before processing a new frame, users should verify:

1. `PATH_NUM` is exactly **3 digits**
2. `FRAME_NUM` is exactly **4 digits**
3. `BASE_DIR` matches the real environment
4. `load_isce` activates the expected conda environment
5. `reference/*.xml` exists after stack preparation
6. interferogram outputs follow the expected naming
7. delivery folder names match `${FRAME_TAG}` exactly

---

## 8. Current Repository Layout

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

## 9. Audit History

This section preserves both the original and updated audit records.

---

## Audit A — Original Cross-Audit of Manual v2.1 and Scripts

**Document audited:** `LInOG_InSAR_Processing_Manual_v2.1.md`  
**Audit type:** Initial cross-analysis of manual ↔ uploaded scripts  
**Status at time of audit:** Issues identified before repository correction

### A.1 Critical Bugs Found

| ID | Severity | File | Original Finding |
|----|----------|------|------------------|
| B1 | Critical | `linog_save_insar_images.py` | `mag_norm[p_high == p_low] = 0` used a scalar bool as an array index and could raise `IndexError` |
| B2 | Critical | `linog_fbs_processor.sh` | `mintpy.load.metaFile = .../reference/IW1.xml` was Sentinel-1/TOPS-specific and not appropriate for ALOS stripmap |
| B3 | Critical | `linog_fbs_processor.sh` | `filt_fine.unw`, `filt_fine.cor`, `filt_fine.unw.conncomp` matched topsStack naming, not stripmapStack date-pair naming |
| B4 | Critical | `linog_fbs_processor.sh` | Phase 4.5 printed `save_insar_images.py` and `create_grid.py` without `linog_` prefix |

### A.2 Minor Bugs Found

| ID | Severity | File | Original Finding |
|----|----------|------|------------------|
| B5 | Minor | `linog_save_insar_images.py` | Usage message used wrong script filename |
| B6 | Minor | `linog_gen_interactive_kmz.py` | `matplotlib.pyplot` imported inside helper function repeatedly |
| B7 | Minor | `linog_gen_interactive_kmz.py` | Used deprecated `plt.cm.jet` access |

### A.3 Manual ↔ Script Discrepancies Found

| ID | Area | Finding |
|----|------|---------|
| D-OLD-1 | Phase 4.5 manual vs script echo block | Manual correctly used `linog_` filenames, while the shell script did not |
| D-OLD-2 | MintPy outputs | `geo_timeseries_ramp_demErr.h5` mapping for `demErr_ramp` was confirmed correct |
| D-OLD-3 | Deliverables naming | Phase 6 output naming was confirmed consistent |

### A.4 Initial Felix Assumptions Flagged

| ID | Area | Finding |
|----|------|---------|
| F-OLD-1 | Server paths | `/eggraid/...` was assumed environment-specific |
| F-OLD-2 | Internal tools | `find_alos.sh`, `run_unpack_all_cli.py`, and `poststep04_cleanup.py` could not be externally verified |
| F-OLD-3 | Reference date | `20091111` was only known-good for specific frames and not universally guaranteed |

### A.5 Initial External Warnings

| ID | Area | Finding |
|----|------|---------|
| W-OLD-1 | DEM source | ESA STEP auxiliary DEM URL may be unreliable at times |
| W-OLD-2 | Python version concern | Earlier concern about Python 3.12 support was later retracted after verification |

### A.6 Items Originally Verified Correct

- `linog_create_grid.py` logic
- KMZ correction mapping
- deliverable suffix logic
- MintPy command usage
- stripmapStack parameter pattern
- dual use of `los.rdr` for angular data
- interactive KMZ timeseries indexing

---

## Audit B — README v2.2 Parameterization and Repository-State Update

**Document audited:** `README.md`  
**Audit type:** Repository-state update after fixes and documentation rewrite  
**Status:** Current

### B.1 Documentation Updates Introduced

- manual wording changed from **students** to **users**
- workflow rewritten to support reusable Path/Frame variables
- commands updated to reduce hardcoded frame references
- local and felix setup clarified using variable blocks

### B.2 Repository-State Conclusions

- All critical issues from Audit A are fixed in the committed scripts
- All minor issues from Audit A are fixed in the committed scripts
- Remaining caveats are operational or environment-specific, not repository code defects

---

## 10. Final Status

### Code status
- Critical issues: **fixed**
- Minor issues: **fixed**

### Documentation status
- current manual version: **2.2**
- audit history preserved: **yes**
- reusable Path/Frame workflow: **yes**

### Remaining limitations
- server-specific items still require verification in the real felix environment

---

*End of ERRATA*
