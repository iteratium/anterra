# Deprecation Warnings — Remediation

Warnings surfaced in the `ansible-apply` log. Ordered by effort/risk. Fold each
into the next relevant change; status noted per item.

## 1. GitHub Actions: Node 20 EOL (quick, safe)

`actions/checkout@v4` and `actions/setup-python@v5` target Node 20 (forced onto
Node 24). The `punycode` / `trace-deprecation` lines are downstream of this.

- Fix: bump to `actions/checkout@v5` and `actions/setup-python@v6` in all
  workflows (terraform + ansible).

## 2. Ansible: Python interpreter discovery (quick, safe)

One warning per host (mediacenter 3.14, pve/rpi 3.13, vps 3.12) about
auto-discovered interpreters.

- Fix: `interpreter_python = auto_silent` in `ansible.cfg [defaults]`.

## 3. Ansible: apt_repository deprecated (track upstream)

`apt_repository` → `deb822_repository`; removed in ansible-core 2.25. Originates
inside `geerlingguy.docker`, not our code.

- Fix (a): DONE — CI installs a pinned `ansible-core` (was `pip install
  ansible`, unpinned), so an upgrade to 2.25 can't silently break the role.
- Fix (b): track geerlingguy.docker for a deb822 migration, then unpin.

## 4. Ansible: INJECT_FACTS_AS_VARS default True (needs testing, defer)

Removed in ansible-core 2.24. `inject_facts_as_vars = False` is the fix, but
`geerlingguy.docker` reads top-level `ansible_*` fact vars, so flipping it may
break the role. Needs a test apply. The ansible-core pin (#3a) buys time.
