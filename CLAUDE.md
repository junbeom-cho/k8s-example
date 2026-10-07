# CLAUDE.md

This repo holds declarative deployment config (Helm values + hand-written manifests) for a single-node **K3s** home server
that is **no longer running**; it is kept as an archive / example. Follow the repository guidelines below. The rules
(directory = namespace, file names, version-check headers, `change-me` secrets) are spelled out in `README.md`, and
`docs/INFRASTRUCTURE.md` holds the architecture and the final live snapshot (2026-07-21).

@AGENTS.md

## Working In This Repo
- The cluster is not running: there is nothing to `kubectl get` or deploy to, so the files are the source of truth. Do not run `kubectl` / `helm` against a cluster unless the user sets one up and asks, and never invent chart/image versions or repo URLs — write `확인 필요` when unknown.
- No migration is in progress. The per-service layout (directory = namespace; exceptions `longhorn-system`, `metallb-system`, `kube-system`) is final; do not reintroduce grouped `apps/` / `core-infra/` / `monitoring/` directories or namespaces.
- Secrets exist only as templates: `secret.yaml.example` (every sensitive value `change-me`) + `secret-sync.yaml.example` (`InfisicalSecret`). Never write real values into tracked files; filled-in `secret.yaml` copies are git-ignored.
- Keep edits minimal and textual, and keep the version-check header at the top of every values file, manifest, and `*.example`.
