# CI/CD — Planned

Design decisions recorded during setup. Terraform plan/apply workflows
(`.github/workflows/terraform-plan.yml`, `terraform-apply.yml`) and Ansible
check/apply workflows (`ansible-check.yml`, `ansible-apply.yml`) exist. See
`plans/mediacenter-vm.md` for Terraform implementation notes and
`plans/docker-portainer.md` for the Docker/Portainer rollout.

**Terraform, not OpenTofu** (old repo used OpenTofu). Uses
`hashicorp/setup-terraform` and the `terraform` binary.

## Runner

GitHub-hosted runners, not self-hosted. This fleet has no control node; an
ephemeral per-job runner is the control node. (User's reasoning: GitHub's
infrastructure is more resilient than any fleet host.)

- Joins the tailnet via `tailscale/github-action` with `--ephemeral`
  (auto-deregisters on disconnect).
- Auth: a Tailscale OAuth client scoped to `tag:ci-runner`
  (`TS_OAUTH_CLIENT_ID`/`SECRET`) — see `setup/tailscale.md` (`OAuth clients`).

## Secrets

No Bitwarden. All secrets — Ansible and Terraform — are GitHub Actions secrets,
injected at runtime (env vars / `--extra-vars` / `TF_VAR_*`). No `bws` token,
`ansible-vault` file, or `bitwarden.tofu` provider (old repo used one).

## Terraform state

HCP Terraform (free tier); see `setup/terraform.md`. No control node to hold
local state between runs, and it pairs natively with `terraform`.

## Ansible

- **Targeting**: inventory points at Tailscale MagicDNS names / `100.x` IPs, not
  LAN IPs — the runner's only path is the tailnet.
- **Entrypoint**: single `site.yml`. Trigger on any `ansible/**` change and run
  the whole thing — cheap at 3 hosts, avoids change-detection logic.
- **PR preview**: `ansible-playbook --check --diff`, stdout captured into a
  generic PR-comment action (no off-the-shelf equivalent to Terraform's
  plan-comment actions). `--check` isn't a perfect analog to `terraform plan`
  (shell/command tasks report inaccurately) — treat as preview, not guarantee.

## Trigger model

Auto-plan/check on PR, apply gated behind manual approval on merge.

- PR opened/updated (path-filtered): `terraform/**` → `terraform plan`;
  `ansible/**` → `ansible-playbook --check --diff`. Posted as PR comments.
- Merge to `main` → apply workflow auto-triggers, pauses at the `production`
  GitHub Environment for manual approval. Keeps merge and apply as two
  deliberate actions without a separate remembered step, and avoids `main`
  drifting from the fleet.
- Approved → apply runs on the same ephemeral-runner + Tailscale-join pattern.

The approval click replaces "explicit chat permission" from the manual-ops era.

## Branching model

GitHub Flow — short-lived topic branches, squash-merge into `main`. No `dev`
branch: only one environment exists, so `dev` would add a merge hop isolating
nothing; the PR plan/diff comments are the safety net.

Branch protection on `main`: plan/check as a required status check. Terraform
`plan` is configured (`setup/github.md`); add the Ansible `check` job to the
required checks. Stub workflows (`terraform-plan-stub.yml`,
`ansible-check-stub.yml`) satisfy the required check on PRs that don't touch
that path.

## Change process

1. Branch off `main`, edit `terraform/`/`ansible/`, commit, push, open PR.
2. CI posts the relevant plan/diff comments; push to rerun.
3. Squash-merge once checks pass.
4. Apply auto-triggers, pauses at the `production` gate.
5. Approve in the Actions tab → apply runs.
