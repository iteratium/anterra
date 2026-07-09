# CI/CD — Planned

Decisions made during setup planning, ahead of actually building the automation
(see repo phase: manual host setup first, automation build-out later — this
doc records design). The Terraform plan/apply workflows now exist
(`.github/workflows/terraform-plan.yml`, `terraform-apply.yml`); Ansible's
`site.yml` workflow does not yet. See `plans/mediacenter-vm.md` for the
implementation notes and remaining manual steps for the Terraform side.

**Terraform, not OpenTofu.** Old repo used OpenTofu; v2 uses actual Terraform
(the `terraform/` directory name already reflects this). Relevant here since
it changes which CLI/setup-action the workflow uses (`hashicorp/setup-terraform`,
`terraform` binary) and rules out OpenTofu-specific tooling.

## Runner

**GitHub-hosted runners**, not a self-hosted runner on any fleet host.

- No control node in this fleet's design — a GitHub-hosted runner acts as an
  ephemeral, per-job control node instead.
- Reasoning (user's own words): GitHub's infrastructure is far more resilient
  than any of the fleet hosts.
- Job joins the tailnet via `tailscale/github-action`, using `--ephemeral` so
  the device auto-deregisters when the job disconnects (no leftover devices in
  the tailnet device list).
- Auth: a Tailscale **OAuth client** (not a static authkey) — scoped, revocable
  without hunting down a leaked key. Stored as `TS_OAUTH_CLIENT_ID` /
  `TS_OAUTH_CLIENT_SECRET` in GitHub Actions secrets, scoped only to
  `tag:ci-runner` — separate from the `tag:mediacenter`-scoped client
  Terraform itself uses (`TS_OAUTH_MEDIACENTER_CLIENT_ID`/`SECRET`), see
  `setup/tailscale.md` (`OAuth clients` section) for why they can't share
  one client.

## ACL change (done)

The ephemeral runner joins as `tag:ci-runner`, with its own `ssh` rule
(couldn't share the `group:fleet-admins` rule — `autogroup:self` in `dst`
only works when `src` is exclusively users/groups). `pve`/`rpi` were tagged
`tag:fleet-host` so the runner's rule can reach them. See `setup/tailscale.md`
(`tag:ci-runner and tag:fleet-host` section) for the full policy and
reasoning.

## Secrets

**No Bitwarden Secrets Manager.** All secrets — Ansible and Terraform both —
live directly as GitHub Actions secrets and are injected into the job at
runtime (env vars / `--extra-vars` / `TF_VAR_*`). No `bws` machine-account
token, no `ansible-vault` password file, no `bitwarden.tofu` provider (old
repo used one per `opentofu/*` stack — not carried over). GitHub Actions
secrets are the single source of truth for both tools.

## Terraform state

**HCP Terraform (Terraform Cloud, free tier)** — org and project already
created. Chosen because there's no control node to hold local state on disk
between runs, and it pairs natively with `terraform` (part of why OpenTofu
was dropped). State lives there, not in the repo; no state file to commit
back. Referred to as TFC for brevity elsewhere in this doc.

## Ansible targeting

Inventory should point at Tailscale MagicDNS names or `100.x` IPs, not LAN
IPs — the runner's only path to the fleet is the tailnet.

## Ansible entrypoint

Single `site.yml` at the root of `ansible/`, not one workflow per playbook.
Convention (confirmed via research, not just a guess): trigger the whole
workflow on any change under `ansible/**` (`playbooks/**`, `roles/**`,
`inventory/**`, `group_vars/**`, `host_vars/**`) and run the full `site.yml`
every time — cheap and safe at 3 hosts, avoids building change-detection
logic to figure out which playbook(s) to run.

`ansible-playbook --check` is not a perfect analog to `terraform plan` —
some modules (shell/command tasks, some package managers) don't report
accurately in check mode. Treat the PR diff as a helpful preview, not a
guarantee, the way a Terraform plan is.

No off-the-shelf action posts `ansible-playbook --check --diff` output as a
PR comment (unlike Terraform's plan-comment ecosystem) — capture the step's
stdout and feed it into a generic PR-comment action (e.g.
`peter-evans/create-or-update-comment` or
`marocchino/sticky-pull-request-comment`).

## Trigger model

**Auto-plan/check on PR, apply gated behind manual approval on merge.**

- PR opened/updated → CI auto-runs (path-filtered):
  - `terraform/**` changed → `terraform plan` (against TFC state) posted as
    a PR comment.
  - `ansible/**` changed → `ansible-playbook --check --diff` against
    `site.yml` posted as a PR comment.
- PR merged to `main` → apply workflow auto-triggers, but pauses at a GitHub
  Environment (e.g. `production`) requiring manual approval in the Actions
  tab before it proceeds. Chosen over a fully independent `workflow_dispatch`
  so merge and apply stay two distinct deliberate actions without relying on
  remembering a separate manual step, and `main` doesn't sit drifted from
  the real fleet for long stretches.
- Approved → apply job runs (`terraform apply` via TFC, `ansible-playbook`
  real run of `site.yml`) on the same ephemeral GitHub-hosted runner +
  Tailscale join pattern as the check job.

This carries over the existing policy of never running system-changing
automation without an explicit human action — the approval click is that
action, replacing "explicit chat permission" from the manual-ops era.

## Branching model

**GitHub Flow** — short-lived topic branches off `main`, PR into `main`,
squash merge. No persistent `dev` branch: a `dev` branch earns its keep when
there's a separate environment to validate against before touching
production, and this fleet has exactly one environment (`pve`/`rpi`/`vps`).
The safety net is the PR's plan/diff comments, which apply the same whether
the PR comes from a topic branch or a `dev` branch — so `dev` would just add
an extra merge hop with nothing to isolate.

**Branch protection on `main`**: require the plan/check workflow to pass as
a required status check before merge is allowed. Configured for the
Terraform `plan` check (see `setup/github.md`); add the Ansible check job
too once that workflow exists.

## Full change process

1. `git checkout -b <topic>` off `main`.
2. Edit `terraform/` and/or `ansible/` files, commit.
3. Push, open a PR against `main`.
4. CI auto-runs the relevant check(s) (see Trigger model) and posts
   plan/diff as PR comments. Push more commits if something's off; CI
   reruns each push.
5. Merge (squash) once the plan/diff look right and required checks pass.
6. Apply workflow auto-triggers on `main`, pauses for manual approval on the
   `production` environment gate.
7. Approve in the Actions tab → apply runs → fleet reflects the change.
