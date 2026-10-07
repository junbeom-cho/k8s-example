# Repository Guidelines

## Status
This repository is an **archive / example**. The single-node K3s home server it configured is **no longer operated**, so there is no live cluster to inspect or deploy to — the files themselves are the record. Every file reflects its last-used state, and every `values*.yaml`, manifest, and `*.example` starts with a version-check header: before reusing a service, compare the chart/image versions in that header with the latest upstream releases and their breaking changes.

The repository rules are documented in [`README.md`](README.md) (Korean). Architecture, platform internals, and the final live snapshot (2026-07-21) are in [`docs/INFRASTRUCTURE.md`](docs/INFRASTRUCTURE.md).

## Project Structure & Module Organization
- **Directory = namespace.** Each top-level service directory is exactly one Kubernetes namespace with the same name (`vaultwarden/` → ns `vaultwarden`). The only exceptions use the namespace their upstream project designates: `longhorn/` → `longhorn-system`, `metallb/` → `metallb-system`, `keel/` → `kube-system`.
- **Related components share a directory.** An app and its dedicated DB/cache/companions live together: `quartz/` (blog + Syncthing + CouchDB), `homarr/` (Homarr + Valkey), `snapotter/` (SnapOtter + Valkey), `shlink/` (backend + web), `ai-stack/` (Ollama + Open WebUI). Databases shared by several apps live in `database/` (PostgreSQL + MariaDB + CloudBeaver), reached at `postgres.database.svc.cluster.local:5432` and `mariadb.database.svc.cluster.local:3306`; per-app DBs/users are created with `database/create-db.sql`.
- **File names inside a service directory:**
  - `values.yaml` when the directory's app is a single Helm chart; `values-<component>.yaml` when there are several charts (e.g. `homarr/values-homarr.yaml` + `values-valkey.yaml`) or a chart sits next to a hand-written app manifest (`<app>.yaml`, e.g. `snapotter/snapotter.yaml` + `values-valkey.yaml`). A chart with only supporting manifests next to it keeps `values.yaml` (e.g. `cert-manager/values.yaml` + `cluster-issuer.yaml`). No vendor suffixes such as `-helmforge`; the chart source goes in the header.
  - `<app>.yaml` for a hand-written manifest (e.g. `mealie/mealie.yaml`). Supporting manifests next to a Helm chart use a descriptive kebab-case name (`cluster-issuer.yaml`, `cloudflare-only.yaml`, `metallb-config.yaml`, `crowdsec-traefik-bouncer.yaml`, `minio-cli.yaml`).
  - `secret.yaml.example` holds all `Secret` templates of the namespace in one multi-document file; `secret-sync.yaml.example` holds all `InfisicalSecret` resources of the namespace. Neither exists when the app reads no Secret.
  - Other data files keep their names: `homepage/config/*`, `minio/policy/*`, `database/create-db.sql`, `snapotter/docker-compose.yml` (upstream reference only, never applied).
- When adding a service that ships only a `docker-compose.yml`, scaffold from [`docs/templates/`](docs/templates/README.md) (Namespace + ConfigMap + PVC + Deployment + Service + Ingress, plus `secret.yaml.example` / `secret-sync.yaml.example`) instead of hand-writing manifests. `docs/templates/` is a scaffold, not a namespace.
- Do not reintroduce grouped directories or namespaces (`apps/`, `core-infra/`, `monitoring/`).

## Platform Context (historical, as last operated)
Single-node K3s (`techbara-server`, `192.168.50.200`, K3s `v1.35.5+k3s1`). Key platform pieces:

- **Traefik** is the ingress controller (`ingressClassName: traefik`), exposed via **MetalLB** (`LoadBalancer` `192.168.50.210`, pool `192.168.50.210-250`).
- **cert-manager** issues TLS through ClusterIssuer `letsencrypt-cloudflare` (DNS-01 / Cloudflare). The domain is `*.techbara.dev`.
- Traefik Middlewares all live in ns `traefik` and are referenced as `traefik-cloudflare-only@kubernetescrd`, `traefik-crowdsec-bouncer@kubernetescrd`, and `traefik-authentik-forwardauth@kubernetescrd`.
- **Longhorn** is the block storage backend (`storageClassName: longhorn`). Both `local-path` and `longhorn` were marked default — always set `storageClassName: longhorn` explicitly on PVCs.
- **Infisical** + secrets-operator manage secrets; **Authentik** (Traefik forwardAuth) and **CrowdSec** guard ingress.

## Secrets Pattern
Each service directory pairs `secret.yaml.example` (Secret templates, every sensitive value `change-me`) with `secret-sync.yaml.example` (`InfisicalSecret` CRDs that sync the real values from Infisical into those Secrets). Every `InfisicalSecret` uses `hostAPI: https://infisical.techbara.dev/api` and authenticates with the `infisical-auth-token` Secret in ns `infisical` — a bootstrap credential that is always created by hand (see `infisical/secret.yaml.example`). Without Infisical, copy `secret.yaml.example` to `secret.yaml`, fill in the values, and apply it; filled-in `secret.yaml` / `secret-sync.yaml` files are git-ignored.

The repository is public. Never commit real credentials anywhere — values files, manifests, comments, `*.example`. Use `change-me` for passwords, tokens, API keys, webhook URLs, session/encryption keys, and similar; in connection strings replace only the credential part (`postgresql://app:change-me@postgres.database.svc.cluster.local:5432/app`). Keep references (Secret names, key names, `existingSecret`) intact. There is no pre-commit hook any more (husky was removed), so run `gitleaks protect --staged --verbose` (or `gitleaks detect --source . --no-git`) by hand before committing. `*.env` is git-ignored.

## Build, Test, and Development Commands
There is no central `Makefile` and no running cluster; validate per service. The `Install` / `Apply` lines in file headers assume you run them from inside the service directory; the commands below run from the repository root.

- `python3 -c "import yaml,sys; [list(yaml.safe_load_all(open(f))) for f in sys.argv[1:]]" <files>`: offline YAML syntax check (include `*.example`)
- `helm template vaultwarden helmforge/vaultwarden -n vaultwarden -f vaultwarden/values.yaml`: render a Helm release (needs the chart repo but no cluster; add `--version <chart version from the header>` to pin)
- `kubectl apply --dry-run=client -f mealie/mealie.yaml`: validate a hand-written manifest (kubectl still needs API discovery from some reachable cluster, e.g. a throwaway kind/k3d cluster)
- `helm upgrade --install traefik traefik/traefik -n traefik --create-namespace -f traefik/values.yaml`: deploy a Helm-managed service when reusing it
- `kubectl apply -f mealie/mealie.yaml`: apply a hand-written manifest when reusing it

## Coding Style & Naming Conventions
Use 2-space YAML indentation and keep Kubernetes field order conventional: `apiVersion`, `kind`, `metadata`, `spec`. Keep filenames lowercase and hyphenated, following the naming rules above.

Preserve repository patterns:

- the version-check header at the top of every values file, manifest, and `*.example` (format in `README.md`); write unknown chart/app versions or repo URLs as `확인 필요` instead of guessing
- a `kind: Namespace` document at the top of hand-written manifests, and an explicit `namespace` equal to the directory's namespace on every namespaced resource
- `ingressClassName: traefik`, `cert-manager.io/cluster-issuer: letsencrypt-cloudflare`, and hosts on `*.techbara.dev` for ingress resources
- `storageClassName: longhorn` on PVCs
- `change-me` for every sensitive value
- minimal, text-level edits to values files — never round-trip them through a YAML library (comments and ordering would be lost)

## Testing Guidelines
This repo does not include an automated test suite. Validation is configuration-focused:

- parse every edited YAML file, including `*.example`, with the command above
- run `helm template` for every edited `values*.yaml`
- check ingress hosts, Secret names and keys against what the config reads, `storageClassName`, referenced PVCs, and that no real credential slipped in

## Commit & Pull Request Guidelines
Commits use a conventional prefix and a short imperative subject, mostly in Title Case, such as `feat: Add Snapotter`, `fix: Remove brevo-secret for Hoppscotch`, and `refactor: Change postgresql from bitnami to helmforge`. Keep each commit scoped to one service or one infrastructure change.

PRs should state the affected directory/namespace and service, note any domain/TLS/secret changes, and call out storage or database impact. Include screenshots only when changing user-visible Homepage configuration.

## Security & Configuration Tips
`.env` files and filled-in `secret.yaml` / `secret-sync.yaml` copies are ignored by Git; keep real credentials there or in Infisical. Tracked files, including every `*.example`, must contain only `change-me` placeholders for sensitive values.
