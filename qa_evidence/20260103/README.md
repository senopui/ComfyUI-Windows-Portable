# QA evidence pack (20260103)

This folder captures a compact, in-repo summary of the evidence bundle used to verify the latest cu130-nightly run.

## Contents
- `00_context.md`: run link, commit SHA, and evidence bundle URL.
- `01_accel_manifest_summary.md`: accelerator manifest table (exact values from `accel_manifest.json`).
- `02_key_log_excerpts.md`: short, high-signal log excerpts from the CI build log.

## Regeneration
1. Download the evidence bundle referenced in `00_context.md`.
2. Extract it locally and locate:
   - `accel_manifest.json`
   - `logs_*/0_build_upload.txt`
3. Recreate the markdown summaries using the exact values from the extracted files.

Docs/evidence only; no workflow/build changes.
