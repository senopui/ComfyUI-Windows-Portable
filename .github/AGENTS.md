# Agent Guidance (.github)

This repo relies heavily on GitHub Actions workflows. Workflow changes can break builds fast.

## Workflow norms
1) Always start with `/plan` for workflow changes.
2) Do not change stable cu130 behavior unless unavoidable and justified.
3) Prefer additive, gated logic over removing functionality.

## Diagnostics rules (nightly)
- Any “nightly diagnostics” step must use the **builder python_standalone** (not `python` from PATH).
- Avoid fragile quoting:
  - Prefer PowerShell here-strings piped into python via stdin.
- Diagnostics should not fail the build due to missing optional accelerators:
  - torch import failure = hard fail
  - optional accel import failure = warn only

## PowerShell preflight
- Preflight should parse-check installer scripts **before** stage1 runs:
  - `[scriptblock]::Create((Get-Content -Raw $scriptPath)) | Out-Null`
- When printing script names, do NOT write `$script:` in a double-quoted string.
  - use `("{0}" -f $script)` or `"${script}"`

## CI truthfulness
- If CI wasn’t run (docs-only PR, sandbox limits), say:
  - “CI not triggered in this environment.”
- Don’t write “YAML invalid” when it was just missing PyYAML locally.

## Evidence expectations in PRs
- For workflow/script changes: include links to relevant Actions runs.
- For build fixes: include the first fatal error signature you fixed.
