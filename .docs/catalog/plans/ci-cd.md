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
- **Entrypoint**: `site.yml`, but per-play selection avoids re-running
  everything. A composite action (`.github/actions/ansible-select`) maps changed
  paths (`dorny/paths-filter`) to the affected playbooks; a change to shared
  files (`inventory/`, `requirements.yml`, `site.yml`) runs the full `site.yml`.
  Check and apply share this action, so the path map lives in one place.
- **PR gate**: hard-fail on `--syntax-check` and an all-hosts `ping`; these are
  the blocking checks (`check` job).
- **PR preview**: `ansible-playbook --check --diff`, stdout captured into a
  generic PR-comment action (no off-the-shelf equivalent to Terraform's
  plan-comment actions). Non-blocking — `--check` isn't a perfect analog to
  `terraform plan`: it reports failures for first-time installs (a repo must be
  added before its packages are visible) and shell/command tasks report
  inaccurately. Treat as preview, not guarantee.

### Run performance

Tasks run from a GitHub-hosted runner to fleet hosts over Tailscale, where
per-task SSH setup dominated (~15s floor per task, even for no-op tasks).
`ansible.cfg`:

- **ControlPersist** (`ControlMaster=auto ControlPersist=60s`) reuses one SSH
  connection across a host's tasks instead of reconnecting per task.
- **Pipelining** (`pipelining = true`) collapses each task's several SSH
  round-trips into one; safe because `ansible_user` is `root` (no `requiretty`).
- **Fact caching** (`gathering = smart`, jsonfile) gathers facts once per run
  instead of once per play (`site.yml` has five fact-gathering plays).

### Reproducibility

- CI installs a pinned `ansible-core`, not the floating `ansible` bundle;
  collections come solely from `requirements.yml`, all version-pinned.
- Tailnet join + install is a composite action
  (`.github/actions/ansible-setup`) shared by check and apply.

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
