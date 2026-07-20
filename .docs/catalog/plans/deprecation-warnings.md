# Deprecation Warnings — Remediation

Warnings surfaced in the `ansible-apply` log. Status noted per item.

## 1. GitHub Actions: Node 20 EOL

DONE. `actions/checkout` → `v7`, `actions/setup-python` → `v7`,
`dorny/paths-filter` → `v4`, across all workflows and composite actions. All
three target Node 24. The `punycode` / `trace-deprecation` lines were downstream
of this.

## 2. Ansible: Python interpreter discovery

DONE. `interpreter_python = auto_silent` in `ansible.cfg [defaults]`.

## 3. Ansible: apt_repository deprecated

DONE. `apt_repository` → `deb822_repository`; removed in ansible-core 2.25.
Originated inside `geerlingguy.docker`, not our code. Role pinned to `8.0.0`,
which uses `deb822_repository` and deletes the legacy
`/etc/apt/sources.list.d/docker.list` it wrote previously.

CI installs a pinned `ansible-core` (not the floating `ansible` bundle), so a
core upgrade cannot silently break a role.

## 4. Ansible: INJECT_FACTS_AS_VARS default True

Removed in ansible-core 2.24. `inject_facts_as_vars = False` is the fix. Every
occurrence originated in `geerlingguy.docker` 7.4.1; `8.0.0` reads
`ansible_facts.*` throughout, so the warning should clear without flipping the
setting. Our own playbooks already use `ansible_facts[...]`.

Flip `inject_facts_as_vars = False` once a run confirms no remaining
top-level-fact reads. Left at the default until then — flipping it blind breaks
any dependency that still reads bare `ansible_*`.
