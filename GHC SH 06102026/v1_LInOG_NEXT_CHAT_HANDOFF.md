# LInOG InSAR Processing Handoff — 2026-06-10

## Role/context for next assistant

Act as a Remote Sensing Scientist & InSAR Engineer supporting ALOS PALSAR-1 / ISCE2 / MintPy processing on `felix`.

Primary remote server:

```text
arieln@felix:/eggraid/home/arieln/projects/linog/insar/
```

Canonical environment:

```text
/eggraid/miniconda3/envs/linog_isce2
```

Main repo:

```text
Ayiemeyzing/LInOG_InSAR_Processing
```

Environment standard document already added to repo:

```text
ENVIRONMENT_STANDARD_Version3.md
```

Source URL:

```text
https://github.com/Ayiemeyzing/LInOG_InSAR_Processing/blob/14f67eff0dde3a00023202e83d06720fd974e9d0/ENVIRONMENT_STANDARD_Version3.md
```

---

# 1. Environment state

The user has shell helper commands:

```bash
linog_isce2
linog_envinfo
linog_off
```

Expected environment provenance:

```text
CONDA_PREFIX=/eggraid/miniconda3/envs/linog_isce2
python3=/eggraid/miniconda3/envs/linog_isce2/bin/python3
gdalinfo=/eggraid/miniconda3/envs/linog_isce2/bin/gdalinfo
stackStripMap.py=/eggraid/miniconda3/envs/linog_isce2/share/isce2/stripmapStack/stackStripMap.py
```

Important: We found that the old activator was leaving `set -e` and `pipefail` enabled in the interactive shell, which caused SSH sessions to close after normal command failures.

The fixed activator is:

```text
/eggraid/home/arieln/linog_repo/env/activate_linog_isce2.sh
```

It should **not** leave `errexit`, `nounset`, or `pipefail` enabled.

User tested:

```bash
set +e
set +u
set +o pipefail

linog_isce2

set -o | grep -E 'errexit|nounset|pipefail'
false
echo "Shell survived false."
find /definitely/not/a/real/path -maxdepth 1 2>/dev/null | wc -l
echo "Shell survived failed find pipeline."
```

Result confirmed shell survived and flags remained off.

If needed, verify:

```bash
bash -n /eggraid/home/arieln/linog_repo/env/activate_linog_isce2.sh
tail -30 /eggraid/home/arieln/linog_repo/env/activate_linog_isce2.sh
```

---

# 2. Batch script created

A v1 batch script was written here:

```text
/home/arieln/linog_batch_path_frame_ph0to4_v1.sh
```

Permissions:

```text
-rwxrwxr-x
```

Purpose:
- automate ISCE2 stripmapStack phase 0 through run_05
- preflight
- stack generation
- run_01_reference
- run_02_focus_split
- run_03_geo2rdr_coarseResamp
- run_04_refineSecondaryTiming
- run_05_invertMisreg
- logging and QC
- self-heal one F0290-style bad-date poisoning case

Important bug found and fixed:
- Original script converted frame `0300` to `0192` because bash treated leading-zero integers as octal.
- Fixed lines are now:

```bash
PATHNUM="$(printf "%03d" "$((10#$PATHNUM))")"
FRAMENUM="$(printf "%04d" "$((10#$FRAMENUM))")"
```

Verify:

```bash
grep -nE 'PATHNUM=|FRAMENUM=' ~/linog_batch_path_frame_ph0to4_v1.sh | head -20
bash -n ~/linog_batch_path_frame_ph0to4_v1.sh
```

Expected:

```text
19:PATHNUM="$(printf "%03d" "$((10#$PATHNUM))")"
20:FRAMENUM="$(printf "%04d" "$((10#$FRAMENUM))")"
```

---

# 3. Batch script behavior/caveat

The batch v1 currently assumes this frame layout:

```text
/eggraid/home/arieln/projects/linog/insar/p${PATH}/f${FRAME}
```

and expects at minimum:

```text
SLC/
DEM/
```

For a target like `447 0300`, it expects:

```text
/eggraid/home/arieln/projects/linog/insar/p447/f0300/SLC
/eggraid/home/arieln/projects/linog/insar/p447/f0300/DEM
```

Important safety caveat:
- The self-healing logic originally removed a bad date using `rm -rf "$SLC_DIR/$bad_date"`.
- We discussed patching it to **move** bad SLCs to:

```text
bad_slc_removed_by_batch_v1/YYYYMMDD
```

instead of deleting. This patch may or may not have been applied. Verify before production use:

```bash
grep -n "Removing bad acquisition\|Moving bad acquisition\|rm -rf.*SLC_DIR" -A8 -B4 ~/linog_batch_path_frame_ph0to4_v1.sh
```

Recommended patch if still using `rm -rf`:

```bash
cp ~/linog_batch_path_frame_ph0to4_v1.sh ~/linog_batch_path_frame_ph0to4_v1.sh.bak_badslc_$(date +%Y%m%d_%H%M%S)

python3 - <<'PYEOF'
from pathlib import Path

p = Path.home() / "linog_batch_path_frame_ph0to4_v1.sh"
s = p.read_text()

old = '''    log_msg "Removing bad acquisition ${bad_date}"
    rm -rf "${SLC_DIR:?}/${bad_date}"'''

new = '''    log_msg "Moving bad acquisition ${bad_date} out of active SLC directory"
    BAD_SLC_BACKUP="${FRAME_DIR}/bad_slc_removed_by_batch_v1"
    mkdir -p "$BAD_SLC_BACKUP"

    if [[ -e "${BAD_SLC_BACKUP}/${bad_date}" ]]; then
        stop_new_error "SELFHEAL" "Backup for bad SLC date already exists: ${BAD_SLC_BACKUP}/${bad_date}"
    fi

    mv "${SLC_DIR}/${bad_date}" "${BAD_SLC_BACKUP}/${bad_date}"'''

if old not in s:
    raise SystemExit("Could not find bad-date rm block to patch")

s = s.replace(old, new)
p.write_text(s)
PYEOF

bash -n ~/linog_batch_path_frame_ph0to4_v1.sh
grep -n "Moving bad acquisition" -A10 -B5 ~/linog_batch_path_frame_ph0to4_v1.sh
```

---

# 4. Frame/data state discovered

## P448/F0300

We attempted:

```bash
bash ~/linog_batch_path_frame_ph0to4_v1.sh 448 0300
```

After octal fix it correctly targeted:

```text
/eggraid/home/arieln/projects/linog/insar/p448/f0300
```

But it failed precheck because:

```text
/eggraid/home/arieln/projects/linog/insar/p448/f0300/SLC
```

does not exist.

Inspection showed:

```text
/eggraid/home/arieln/projects/linog/insar/p448/f0300
└── logs/
```

So `p448/f0300` is not prepared and should not be used for phase0–4 batch yet.

An accidental directory from the old octal bug existed:

```text
/eggraid/home/arieln/projects/linog/insar/p448/f0192
```

It was recommended to remove if only logs:

```bash
rm -rf /eggraid/home/arieln/projects/linog/insar/p448/f0192
```

Verify before/after if needed.

## P447/F0300

Original old run existed and was fully populated, but produced failed interferograms. It had:
- `SLC/` with 12 dates
- `DEM/`
- old `configs`, `run_files`, `coregSLC`, `Igrams`, `merged`, `mintpy`, etc.

SLC dates observed in old p447/f0300:

```text
20070117
20070304
20080120
20080421
20081207
20090122
20090309
20091210
20100125
20100312
20110128
20110315
```

DEM listing observed in old p447/f0300 only showed SWBD water-body files:

```text
/eggraid/home/arieln/projects/linog/insar/p447/f0300/DEM/swbdLat_N14_N18_Lon_E120_E123.wbd
/eggraid/home/arieln/projects/linog/insar/p447/f0300/DEM/swbdLat_N14_N18_Lon_E120_E123.wbd.vrt
/eggraid/home/arieln/projects/linog/insar/p447/f0300/DEM/swbdLat_N14_N18_Lon_E120_E123.wbd.xml
```

This may not be the topographic DEM expected by `stackStripMap.py`. Need to search/generate proper DEM later.

## P449/F0300

Also exists and is populated. It has `SLC/`, `DEM/`, `Igrams/`, `mintpy/`, etc. Not the current target.

---

# 5. Archive action already completed

User wanted the **entire old p447/f0300 run** archived, not just derived products, and did **not** want to copy old source data back.

This was done:

```bash
PARENT=/eggraid/home/arieln/projects/linog/insar/p447
OLD_FRAME="${PARENT}/f0300"
ARCHIVE_ROOT="${PARENT}/archive_f0300_old_runs"
ARCHIVE_DIR="${ARCHIVE_ROOT}/f0300_old_products_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$ARCHIVE_ROOT"
mv "$OLD_FRAME" "$ARCHIVE_DIR"
```

Actual archive path created:

```text
/eggraid/home/arieln/projects/linog/insar/p447/archive_f0300_old_runs/f0300_old_products_20260610_091917
```

Then a new empty active frame was created:

```text
/eggraid/home/arieln/projects/linog/insar/p447/f0300
```

At that moment it was empty except the directory itself.

Important: The user clarified that they **do not want to copy old DEM/SLC/raw/unzipped into the new p447/f0300**. They want a true from-scratch rebuild, like was done for `p448/f0290`.

---

# 6. Immediate next task

Create only the empty clean folder structure for the new active frame:

```text
/eggraid/home/arieln/projects/linog/insar/p447/f0300
```

Do **not** copy anything from the archive into it.

Recommended commands:

```bash
set +e
set +u
set +o pipefail

FRAME_DIR=/eggraid/home/arieln/projects/linog/insar/p447/f0300

mkdir -p "$FRAME_DIR"

# Input / staging directories
mkdir -p "$FRAME_DIR/raw"
mkdir -p "$FRAME_DIR/unzipped"
mkdir -p "$FRAME_DIR/SLC"
mkdir -p "$FRAME_DIR/DEM"

# Logs and manual notes
mkdir -p "$FRAME_DIR/logs"
mkdir -p "$FRAME_DIR/manual_run_logs"

# Optional scratch/QC bookkeeping
mkdir -p "$FRAME_DIR/qc"
mkdir -p "$FRAME_DIR/tmp"

echo "Created clean from-scratch folder structure:"
find "$FRAME_DIR" -maxdepth 2 -type d | sort
```

Then write clean rebuild marker:

```bash
FRAME_DIR=/eggraid/home/arieln/projects/linog/insar/p447/f0300

cat > "$FRAME_DIR/README_CLEAN_REBUILD.txt" <<EOF
P447/F0300 clean rebuild started on $(date)

Old full failed run archived at:
/eggraid/home/arieln/projects/linog/insar/p447/archive_f0300_old_runs/f0300_old_products_20260610_091917

This active folder was recreated from scratch.

Policy:
- Do not copy generated products from the old archived run.
- Do not copy old SLC/DEM/raw/unzipped unless explicitly decided later.
- Rebuild raw -> unzipped -> SLC -> DEM -> stackStripMap products cleanly.
- Use linog_isce2 environment only.
EOF

cat "$FRAME_DIR/README_CLEAN_REBUILD.txt"
```

Verify no old generated products:

```bash
FRAME_DIR=/eggraid/home/arieln/projects/linog/insar/p447/f0300

echo "=== top-level contents ==="
find "$FRAME_DIR" -maxdepth 1 -mindepth 1 -printf "%f\n" | sort

echo
echo "=== generated products should NOT exist ==="
for d in configs run_files baselines coregSLC geom_reference Igrams interferograms merged offsets refineSecondaryTiming rejected_pairs mintpy mintpy_logs; do
    if [[ -e "$FRAME_DIR/$d" ]]; then
        echo "WARNING: generated product exists: $d"
    else
        echo "OK absent: $d"
    fi
done
```

Expected active clean frame:

```text
/eggraid/home/arieln/projects/linog/insar/p447/f0300/
├── DEM/
├── README_CLEAN_REBUILD.txt
├── SLC/
├── logs/
├── manual_run_logs/
├── qc/
├── raw/
├── tmp/
└── unzipped/
```

---

# 7. After folder structure: true from-scratch rebuild plan

Do not run `linog_batch_path_frame_ph0to4_v1.sh` yet, because `SLC/` and `DEM/` are empty.

Next major workflow should replicate what worked for `p448/f0290`:

1. Locate/stage original ALOS PALSAR-1 L1.1 CEOS archives for `P447/F0300`.
2. Put raw archives into:
   ```text
   /eggraid/home/arieln/projects/linog/insar/p447/f0300/raw
   ```
3. Unzip into:
   ```text
   /eggraid/home/arieln/projects/linog/insar/p447/f0300/unzipped/YYYYMMDD
   ```
4. Unpack CEOS to ISCE SLCs into:
   ```text
   /eggraid/home/arieln/projects/linog/insar/p447/f0300/SLC/YYYYMMDD
   ```
5. Create or link the correct topographic DEM into:
   ```text
   /eggraid/home/arieln/projects/linog/insar/p447/f0300/DEM
   ```
6. Then run:
   ```bash
   linog_isce2
   bash ~/linog_batch_path_frame_ph0to4_v1.sh 447 0300
   ```

Need to inspect existing scripts in `~/bin` for raw/unzip/unpack workflow:

```text
~/bin/find_alos.sh
~/bin/unzip_ALOS-SLC.py
~/bin/unzip_ALOS-SLC-pol.py
~/bin/unpackFrame_ALOS.py
~/bin/run_unpack_all_cli.py
```

Potential next command to inspect helper usage:

```bash
ls -l ~/bin
sed -n '1,220p' ~/bin/find_alos.sh
sed -n '1,220p' ~/bin/run_unpack_all_cli.py
sed -n '1,220p' ~/bin/unpackFrame_ALOS.py
sed -n '1,220p' ~/bin/unzip_ALOS-SLC.py
sed -n '1,220p' ~/bin/unzip_ALOS-SLC-pol.py
```

Because exact raw-data staging command depends on those helper scripts.

---

# 8. User preference / important guidance

The user explicitly wants:
- clean separation between old failed run and new run
- no contamination from old generated files
- ideally no copying old SLC/DEM/raw/unzipped unless explicitly chosen later
- reproduce the successful `p448/f0290` style step-by-step workflow for `p447/f0300`
- preserve old failed run in archive for comparison
- avoid losing context; they may provide/export the chat as Markdown and/or commit it to GitHub repo for scanning

The assistant should be methodical and cautious:
- always reset shell flags before commands:
  ```bash
  set +e; set +u; set +o pipefail
  ```
- do not assume data is present
- inspect before moving/deleting
- distinguish old archive from active new clean frame
- do not run phase0–4 batch until SLC and DEM are actually prepared

---

# 9. Useful verification commands

Check active clean frame:

```bash
FRAME_DIR=/eggraid/home/arieln/projects/linog/insar/p447/f0300
find "$FRAME_DIR" -maxdepth 2 -type d | sort
```

Check archive exists:

```bash
ARCHIVE_DIR=/eggraid/home/arieln/projects/linog/insar/p447/archive_f0300_old_runs/f0300_old_products_20260610_091917
ls -ld "$ARCHIVE_DIR"
find "$ARCHIVE_DIR" -maxdepth 1 -mindepth 1 -printf "%f\n" | sort
```

Check environment:

```bash
linog_isce2
linog_envinfo
set -o | grep -E 'errexit|nounset|pipefail'
```

Check batch script syntax:

```bash
bash -n ~/linog_batch_path_frame_ph0to4_v1.sh
grep -nE 'PATHNUM=|FRAMENUM=' ~/linog_batch_path_frame_ph0to4_v1.sh | head -20
```

---

# 10. Key mistakes/lessons from this chat

1. Running `/eggraid/...` commands on local laptop caused errors. Always SSH into `felix` first:
   ```bash
   ssh -i ~/.ssh/felix_key arieln@10.207.130.201
   ```

2. Batch script initially converted `0300` to `0192` due to octal parsing. Fixed with `10#`.

3. SSH “closed automatically” because `linog_isce2` left `set -e` and `pipefail` enabled. Fixed by updating activator and `.bashrc` helper, and using:
   ```bash
   set +e
   set +u
   set +o pipefail
   ```

4. `p448/f0300` is not prepared; it only had logs.

5. The old `p447/f0300` was archived entirely to:
   ```text
   /eggraid/home/arieln/projects/linog/insar/p447/archive_f0300_old_runs/f0300_old_products_20260610_091917
   ```

6. New `p447/f0300` should be clean and rebuilt from scratch.