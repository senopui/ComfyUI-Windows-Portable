---
applyTo: ".github/workflows/**"
---

# GitHub Actions workflows (.github/workflows/**)

## Scope/intent
- Workflows must preserve the repo's portability constraints and existing builder stage execution model.

## Shell + working directory conventions (match repo reality)
- Use `shell: bash` explicitly where needed (Windows runners still support bash steps in this repo).
- Use `working-directory: builder*` and run stages as the workflows already do:
  `bash stage1.sh`, `bash stage2.sh`, `bash stage3.sh`

## Validation patterns (match repo reality)
- Keep the existing "launcher validation" idea:
  - run quick-test with a timeout
  - capture logs
  - fail on `Traceback` detection
- Do not add new third-party actions or caching without explicit justification; document patterns when possible.
