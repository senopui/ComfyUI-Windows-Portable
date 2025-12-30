# QA_REPORT (Final)
- Date: 2025-12-30
- Repo / branch: /workspace/ComfyUI-Windows-Portable @ qa/final-qc-20251230
- Commit SHA: ffc88d4f7c9ccb00a317c87701ca81f900717670
- Scope: cu130 + cu130-nightly

## Executive Summary
- Overall status: **FAIL (WORKFLOW ERROR)**
- Local/static verification completed (YAML parsing, shell syntax, Python compileall). Checkout logs were reviewed from attached CI log exports. Both cu130 and cu130-nightly workflows failed early because `builder-cu130/scripts/resolve_python.ps1` raised a PowerShell parser error; fix included in this PR, but CI has not been re-run in this environment. Artifact verification remains unavailable because this checkout has no `origin` remote or GitHub metadata configured.

## Test Matrix
| Check | Evidence | Status |
| --- | --- | --- |
| Local static checks (yaml, shell, python compileall) | **git status:** `## qa/final-qc-20251230`  \
**workflows list:** `build-cu128.yml, build-cu130.yml, build-cu130-nightly.yml, build.yml, copilot-setup-steps.yml, scorecard.yml, test-build.yml`  \
**YAML parse:** `workflows: 7` + each file `ok` via PyYAML  \
**bash -n:** ran on 7 shell scripts (no errors)  \
**compileall:** `scripts/preflight_accel.py`, `scripts/qa_validate_workflow.py`, builder attachments compiled | PASS |
| CI: cu130 workflow run (URL, status) | FAILED — log export `logs_53235648285.zip` shows `ParserError` in `builder-cu130/scripts/resolve_python.ps1:44` (`Variable reference is not valid` from `$ShaUrl:`). | FAIL |
| CI: cu130-nightly workflow run (URL, status) | FAILED — log export `logs_53235644142.zip` shows the same `ParserError` in `builder-cu130/scripts/resolve_python.ps1:44`. | FAIL |
| Artifact verification (downloaded? contents verified?) | NOT RUN — no CI run artifacts accessible from this environment. | NOT RUN |
| Regression signature scan (log search) | NOT RUN — no CI logs available to search. | NOT RUN |
| Checkout logs review | Reviewed attached log exports (`logs_53235644142.zip`, `logs_53235648285.zip`): actions/checkout@v6 ran with `fetch-depth: 1`, `fetch-tags: false`, `clean: true`, and checked out `ffc88d4f7c9ccb00a317c87701ca81f900717670` without errors. | PASS |

## Key Findings
### Fixed items
- Fixed PowerShell parser error in `builder-cu130/scripts/resolve_python.ps1` caused by `$ShaUrl:` string interpolation; this error broke both cu130 and cu130-nightly workflows during Python resolution. (Re-run CI to confirm.)

### Gated/optional items
- Optional accelerator installs are best-effort in cu130-nightly (and partially in cu130 stage1). Missing wheels are logged as **GATED** without failing the workflow; results are captured in `builder-cu130/accel_manifest.json`, and runtime preflight writes/extends the manifest plus disables dependent custom nodes when missing. (See `builder-cu130/scripts/install_optional_accel.ps1` and `scripts/preflight_accel.py`.)
- `SAGEATTENTION2PP_PACKAGE` is an opt-in environment variable; when unset, SageAttention2++ is explicitly gated with a warning in `builder-cu130/scripts/install_core_attention.ps1`.

### Open Issues
- **Severity: High** — cu130 / cu130-nightly workflows failed during Python resolution.
  - **Symptom:** Both workflows exit with `ParserError` in `builder-cu130/scripts/resolve_python.ps1:44`.
  - **Where observed:** attached log exports `logs_53235644142.zip` and `logs_53235648285.zip`.
  - **Likely cause:** PowerShell variable interpolation with a trailing colon (`$ShaUrl:`) invalid for parser.
  - **Recommended fix PR (this change):** use `${ShaUrl}` in the warning string and re-run CI.
- **Severity: Medium** — CI verification unavailable in this environment.
  - **Symptom:** Workflow reruns, artifacts, and regression scans cannot be confirmed locally.
  - **Where observed:** local repo has no `origin` remote; GitHub Actions runs cannot be queried here.
  - **Likely cause:** checkout does not include remote metadata or credentials.
  - **Recommended fix PR (future):** Re-run `build-cu130.yml` and `build-cu130-nightly.yml` and update QA_REPORT with run URLs, artifacts, and regression signature scans.

## Release Readiness Checklist
- [ ] cu130 green
- [ ] cu130-nightly green OR explicitly gated
- [ ] no mystery reds
- [x] docs updated
- [x] QA_REPORT accurate

### Evidence Snippets (local)
```text
$ git status -sb
## qa/final-qc-20251230
```

```text
$ python - <<'PY'
from pathlib import Path
import yaml
paths = sorted(Path('.github/workflows').glob('*.yml'))
print('workflows:', len(paths))
for path in paths:
    data = yaml.safe_load(path.read_text())
    print(f'{path}:', 'ok' if isinstance(data, dict) else type(data))
PY
workflows: 7
.github/workflows/build-cu128.yml: ok
.github/workflows/build-cu130-nightly.yml: ok
.github/workflows/build-cu130.yml: ok
.github/workflows/build.yml: ok
.github/workflows/copilot-setup-steps.yml: ok
.github/workflows/scorecard.yml: ok
.github/workflows/test-build.yml: ok
```

```text
$ for f in $(find builder scripts -name '*.sh'); do echo "## $f"; bash -n "$f"; done
## builder/stage3.sh
## builder/stage2.sh
## builder/generate-pak7.sh
## builder/generate-pak5.sh
## builder/stage1.sh
## builder/attachments/ExtraScripts/force-update-all.sh
## builder/attachments/备用脚本/force-update-cn.sh
```

```text
$ python -m compileall builder scripts
Listing 'builder'...
...
Compiling 'scripts/preflight_accel.py'...
Compiling 'scripts/qa_validate_workflow.py'...
```

```text
$ find . -maxdepth 2 -name '*.log'
```

```text
Attached log export excerpt (logs_53235648285.zip, build_upload/2_Run actions_checkout@v6.txt)
2025-12-30T09:33:31.6495541Z   fetch-depth: 1
2025-12-30T09:33:31.6496313Z   fetch-tags: false
2025-12-30T09:33:31.6495182Z   clean: true
2025-12-30T09:33:34.3214922Z [command]"C:\Program Files\Git\bin\git.exe" -c protocol.version=2 fetch --no-tags --prune --no-recurse-submodules --depth=1 origin +ffc88d4f7c9ccb00a317c87701ca81f900717670:refs/remotes/origin/main
2025-12-30T09:33:34.9816387Z [command]"C:\Program Files\Git\bin\git.exe" checkout --progress --force -B main refs/remotes/origin/main
2025-12-30T09:33:35.1261945Z ffc88d4f7c9ccb00a317c87701ca81f900717670
```

```text
Attached log export excerpt (logs_53235648285.zip, 0_build_upload.txt)
2025-12-30T09:33:40.9804636Z ParserError: D:\a\ComfyUI-Windows-Portable\ComfyUI-Windows-Portable\builder-cu130\scripts\resolve_python.ps1:44
2025-12-30T09:33:40.9804636Z Line |
2025-12-30T09:33:40.9804636Z   44 |     Write-Warning "Failed to fetch SHA256SUMS from $ShaUrl: $($_.Exce …
2025-12-30T09:33:40.9804636Z     |                                                    ~~~~~~~~
2025-12-30T09:33:40.9804636Z     | Variable reference is not valid. ':' was not followed by a valid variable name character.
```
