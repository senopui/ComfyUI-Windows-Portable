# CI Runs
## Dispatch capability
PARTIAL: GitHub CLI not available (`command -v gh` returned non-zero), but two build logs were provided externally.

## cu130 workflow
- Evidence source: `logs_53236406321.zip` → `0_build_upload.txt` (job: build_upload).
- Runner image: windows-2025 (log timestamp 2025-12-30).
- Result: **FAIL** — stage1 aborted when `pip` attempted to clone `cozy_comfy`/`cozy_comfyui` and GitHub prompted for credentials in a non-interactive context.
  - Error excerpt:
    - `fatal: Cannot prompt because user interactivity has been disabled.`
    - `fatal: could not read Username for 'https://github.com': No such file or directory`
    - `ERROR: Failed to build 'cozy_comfy'/'cozy_comfyui'`
- Additional notes:
  - `flash-attn` wheel not found for cp313/torch-nightly (skipped).
  - `spargeattention` wheel not found for this Python+PyTorch+CUDA combination (skipped).

## cu130-nightly workflow
- Evidence source: `logs_53236403191.zip` → `0_build_upload.txt` (job: build_upload).
- Runner image: windows-2025 (log timestamp 2025-12-30).
- Result: **FAIL** — stage1 aborted when `pip` attempted to clone `cozy_comfy`/`cozy_comfyui` and GitHub prompted for credentials in a non-interactive context.
  - Error excerpt:
    - `fatal: Cannot prompt because user interactivity has been disabled.`
    - `fatal: could not read Username for 'https://github.com': No such file or directory`
    - `ERROR: Failed to build 'cozy_comfy'/'cozy_comfyui'`

## cu130-nightly workflow (2026-01-01 run)
- Run: https://github.com/senopui/ComfyUI-Windows-Portable/actions/runs/20641030620
- Logs (zip): https://github.com/senopui/ComfyUI-Windows-Portable/suites/53356684618/logs?attempt=1
- Logs (raw AIO): https://productionresultssa7.blob.core.windows.net/actions-results/a9876153-c473-4513-917d-f3f6801cda4c/workflow-job-run-16d50fd5-e91c-5e24-ab1b-989063625c1d/logs/job/job-logs.txt?rsct=text%2Fplain&se=2026-01-01T16%3A09%3A04Z&sig=zojyjc6mJrwSl%2FwRaj9ui4Nh8aSKdS1jrH%2BqqKPIPyw%3D&ske=2026-01-02T01%3A55%3A10Z&skoid=ca7593d4-ee42-46cd-af88-8b886a2f84eb&sks=b&skt=2026-01-01T13%3A55%3A10Z&sktid=398a6654-997b-47e9-b12b-9515b896b4de&skv=2025-11-05&sp=r&spr=https&sr=b&st=2026-01-01T15%3A58%3A59Z&sv=2025-11-05
- Runner image: windows-2025 (log timestamp 2026-01-01).
- Result: **PASS** — build/upload completed and artifacts published; no fatal errors observed in the job log.
