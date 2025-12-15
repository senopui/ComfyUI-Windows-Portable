---
applyTo: ".github/workflows/**"
---

# GitHub Actions workflows (.github/workflows/**)

## Where to look first
- Existing workflow files in `.github/workflows/` for patterns already in use
- Match conventions present in build-cu128.yml, build-cu130.yml, build-cu130-nightly.yml

## Scope/intent
- Workflows must preserve the repo's portability constraints and existing builder stage execution model.

## Shell + working directory conventions (match repo reality)
- Use `shell: bash` explicitly where needed (match the workflows already present in this repo with bash steps on Windows runners).
- Use `working-directory: builder*` and run stages as the workflows already do:
  `bash stage1.sh`, `bash stage2.sh`, `bash stage3.sh`

## Validation patterns (match repo reality)
- Keep the existing "launcher validation" idea:
  - run quick-test with a timeout
  - capture logs
  - fail on `Traceback` detection
- Do not add new third-party actions or caching without explicit justification; document patterns when possible.
