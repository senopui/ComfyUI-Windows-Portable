# Agent Guidance (builder-cu130)

This directory contains the build stages and installers that define the portable runtime environment.

## Prime directive
- **Make the build reproducible**.
- Optional accelerators are **best-effort**: never hard-fail CI because an accelerator wheel doesn’t exist.

## Track rules
- **Stable (cu130)**: conservative pins, minimal churn.
- **Nightly (cu130-nightly)**: Python 3.13+, Torch nightly/dev, CUDA 13.
  - Nightly-only logic must not leak into stable unless it is a pure bugfix.

## Dependency safety rules
1) **Torch must not be downgraded or swapped to CPU** by pip.
   - If a package tries: use `--no-deps` or gate/skip.
2) **NumPy + Py3.13**:
   - Never allow NumPy 1.x on Py3.13.
   - Prefer wheel-only for NumPy: `PIP_ONLY_BINARY=numpy` (or per-command `--only-binary=numpy`).
3) **VCS installs are optional unless proven required**:
   - Must be non-interactive (`GIT_TERMINAL_PROMPT=0`, `PIP_NO_INPUT=1`)
   - If they fail, warn + continue (unless build truly depends on them).

## PowerShell “do not shoot yourself” rules
- Never put `"$var:"` in double quotes. Use `${var}` or `-f`.
- Never parse JSON from mixed stdout/stderr.
  - If you need JSON: keep stdout pure JSON; treat stderr separately.
- Never run `ConvertFrom-Json` unless you validated it starts with `{` or `[`.

## Skip flags (very important)
- Treat only these values as skip: `1`, `true`, `yes` (case-insensitive).
- `"0"` means **do not skip**.
- Implement a helper in PS scripts, don’t rely on `if ($env:SKIP_X)`.

## Accelerator install policy (core vs optional)
### Core attention installer
- If a core accelerator has no wheel for the matrix:
  - mark as **gated** in `accel_manifest.json`
  - continue the build
- Print a clean summary table at the end.

### Optional accelerators installer
- Order for each accelerator:
  1) public/upstream wheels
  2) source build attempt (nightly only, toolchain permitting)
  3) fallback wheel indexes (e.g., wheels.json / AI-windows-whl)
  4) gated warning + manifest entry

### SpargeAttn (nightly)
- If no compatible wheel:
  - attempt source build from `https://github.com/thu-ml/SpargeAttn` **only if nvcc/toolchain is present**
  - build wheel → install wheel → import test (`import spas_sage_attn`)
  - if build not feasible: warn + gate (do not fail CI)

## Diagnostics guidelines
- Always run diagnostics using the **builder’s python_standalone**.
- Avoid fragile one-liners with `python -c` containing `\n`; prefer stdin scripts / here-strings.

## Handy local checks
- Grep for PowerShell variable-colon traps:
  - `rg '\$[A-Za-z_][A-Za-z0-9_]*:' builder-cu130/scripts -g'*.ps1'`
- Grep for accidental truncation tokens:
  - `rg '\.\.\.' builder-cu130/scripts -g'*.ps1'`
