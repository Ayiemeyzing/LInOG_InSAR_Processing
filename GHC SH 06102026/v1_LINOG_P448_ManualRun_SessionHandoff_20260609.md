# LInOG P448 Manual Run — Session Handoff
**Date:** Jun 9, 2026  
**Author:** Ariel J. Nopre Jr.  
**Continues from:** LINOG_MintPy_SessionHandoff_20260609.md  
**Decision:** Halt batch scripts. Manual rerun of P448 F0280 (and F0290 pending).

---

## Why the Batch Run Produced Gray/No Signal

### Root Cause: run04 (refineSecondaryTiming) Failure → Zero-Shift Coregistration

| Step | Old f0280 run (Mar 6–9, 2026) | Jun 9 batch run (v2.4.2) |
|---|---|---|
| run04 outcome | **SUCCESS** — 980–1109 valid cross-corr points per pair | **FAIL** — empty shelves (100–110 bytes header-only) for all pairs |
| Coregistration | Sub-pixel shifts applied (e.g. az +0.89 px, rg +0.20 px) | Zero-shift fallback (no offset correction) |
| Igrams produced | 36 coherent pairs | 36 pairs but low coherence |
| MintPy pixels | Many — visible signal, coherent velocity maps | 560 pixels at minTempCoh=0.3 — gray/no signal |