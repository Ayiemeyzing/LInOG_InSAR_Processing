# CHANGELOG

All notable changes to this repository, manual, and scripts are documented here.

---

## [2.2] - 2026-05-19

### Added
- reusable Path/Frame variable workflow in `README.md`
- `[LOCAL]` and `[FELIX]` run-variable setup examples
- `CHANGELOG.md` to separate version history from `ERRATA.md`
- improved repository introduction and quick-start structure
- clearer repository contents overview in `README.md`

### Changed
- updated manual wording from **students** to **users**
- reworked command examples to use:
  - `PATH_NUM`
  - `FRAME_NUM`
  - `PADDED_PATH`
  - `PADDED_FRAME`
  - `FRAME_TAG`
  - `BASE_DIR`
  - `WORK_DIR`
- reduced hardcoded frame-specific commands in the workflow
- clarified that reference dates must still be reviewed independently by frame
- updated `ERRATA.md` to preserve both the original audit and the repository-state update

### Fixed
- `scripts/linog_save_insar_images.py`
  - fixed `stretch_magnitude()` scalar-boolean indexing bug
  - corrected usage string to the real filename
- `scripts/linog_gen_interactive_kmz.py`
  - moved `matplotlib` import out of repeated helper scope
  - replaced deprecated `plt.cm.jet` access
- `scripts/linog_fbs_processor.sh`
  - fixed MintPy metadata file pattern for stripmap processing
  - fixed interferogram wildcard patterns for stripmap naming
  - fixed Phase 4.5 printed script names to use `linog_` filenames

### Verified
- Python 3.12 support for conda-forge ISCE2
- `linog_create_grid.py` layout logic
- `CORRECTION_MAP` consistency for interactive KMZ generation
- deliverable naming consistency for `demErr` and `demErr_ramp`

---

## [2.1] - 2026-04

### Added
- pre-flight setup section for local WSL/Linux/macOS users
- vim survival guide
- local and felix installation paths
- `isce2_local` visualization environment instructions
- interferogram visualization workflow
- deliverables checklist and troubleshooting sections

### Documented
- ALOS-1 PALSAR FBS stack workflow using ISCE2 + MintPy
- geocoded deliverables workflow
- interactive KMZ generation workflow
- felix server usage assumptions

### Known state at time of original document
- manual contained several hardcoded frame/path examples
- script/manual inconsistencies were later documented in `ERRATA.md`
- repository packaging and audit tracking were not yet separated into dedicated files

---

## [2.0] - 2026-03

### Added
- initial `linog_fbs_processor.sh` automation workflow
- baseline ISCE2 + MintPy operational structure
- Phase 0 to Phase 7 pipeline framing
- LInOG naming conventions for outputs and logs

---

## Notes

- `ERRATA.md` is for bug findings, assumptions, and audit records
- `CHANGELOG.md` is for version-to-version repository and documentation changes
