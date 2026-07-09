# GitHub — Manual Setup

## Branch protection (`main`)

`Settings` → `Branches` → `Add branch protection rule` (pattern: `main`)

- Require a pull request before merging
- Disallow force pushes
- Disallow deletions

Required status checks: not added yet — depends on the plan/check workflow (see `plans/ci-cd.md`), to be added once that workflow exists.
