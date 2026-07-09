# GitHub — Manual Setup

## Branch protection (`main`)

`Settings` → `Branches` → `Add branch protection rule` (pattern: `main`)

- Require a pull request before merging
- Required approving reviews: **0** — GitHub blocks self-approval, and this
  is a solo-maintainer repo, so requiring someone else's approval would
  permanently block every merge. The PR-required gate plus required status
  checks are the actual review mechanism.
- Disallow force pushes
- Disallow deletions

Required status checks: `plan` (from `terraform-plan.yml`, see `plans/ci-cd.md`) is added. Add the Ansible check workflow's job as a required check too once that workflow exists.

## Environments

`production` — referenced by `terraform-apply.yml`'s `environment: production` gate (see `plans/ci-cd.md`). Created under `Settings` → `Environments` with a required reviewer, so the apply job pauses for manual approval instead of running immediately on merge.
