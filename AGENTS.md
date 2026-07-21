# Repository Guidelines

## Project Structure & Module Organization
This repository stores K3s deployment config, one directory per service (e.g. `vaultwarden/`, `n8n/`, `traefik/`). This per-service layout is the target (see **Refactor In Progress** below).

Grouped directories also exist from an earlier approach that is being unwound — treat them as AS-IS, not the target:

- `apps/`: user-facing services such as `vaultwarden`, `n8n`, `homepage`, and `wordpress`
- `core-infra/`: cluster foundations such as `traefik`, `cert-manager`, and `longhorn`
- `database/`: shared data services such as `postgresql` and `mariadb`
- `monitoring/`: observability and uptime tooling

Most service directories contain either `values.yaml` for a Helm release or one or more plain Kubernetes manifests such as `n8n.yaml` and `*-secret.yaml`. `apps/homepage/config/` holds Homepage-specific YAML data files.

For full cluster topology, live service inventory, and platform internals, see [`docs/INFRASTRUCTURE.md`](docs/INFRASTRUCTURE.md).

## Platform Context
Single-node K3s (`techbara-server`, `192.168.50.200`, K3s `v1.35.5+k3s1`). Key platform pieces:

- **Traefik** is the ingress controller (`ingressClassName: traefik`), exposed via **MetalLB** (`LoadBalancer`, pool `192.168.50.210-250`).
- **cert-manager** issues TLS through ClusterIssuer `letsencrypt-cloudflare` (DNS-01 / Cloudflare). Current domain is `*.techbara.dev` (`*.junbeom.work` is legacy).
- **Longhorn** is the block storage backend (`storageClassName: longhorn`). Note both `local-path` and `longhorn` are marked default — always set `storageClassName: longhorn` explicitly on new PVCs.
- **Infisical** + secrets-operator manage secrets; **Authentik** (Traefik forwardAuth) and **CrowdSec** guard ingress.

## ⚠️ Refactor In Progress
The repo is being refactored and its grouped files do not match the live cluster. Verify with `kubectl get` before applying.

- **Goal (TO-BE)**: one folder **and** one namespace **per service** (e.g. `vaultwarden/` → ns `vaultwarden`, `n8n/` → ns `n8n`).
- **AS-IS (being removed)**: grouped `apps/` `core-infra/` `database/` `monitoring/` folders with grouped namespaces (`namespace: apps`, `core-infra`, `database`). These grouped namespaces are **not deployed live** (except `database`) — the live cluster already uses per-service namespaces, so live is closer to the goal than the grouped repo files are.
- **Domain (separate)**: current domain is `*.techbara.dev` (all live ingress uses it). `*.junbeom.work` is the **old** domain — legacy leftovers in some repo files should be corrected to `techbara.dev`. Confirm real hosts with `kubectl get ingress -A` before applying.

Author new work as **per-service folders + per-service namespaces**. Do not add new services under the grouped `apps/`/`core-infra/` dirs. See [`docs/INFRASTRUCTURE.md`](docs/INFRASTRUCTURE.md) §3.

## Secrets Pattern
Each service pairs a placeholder `*-secret.yaml` (committed template, no real values) with a `*-secret-sync.yaml` (`InfisicalSecret` CRD) that pulls real values from Infisical into that Secret at runtime. The auth token is the `infisical-auth-token` Secret. Never put real credentials in tracked files — `gitleaks` runs on pre-commit and `.env` is git-ignored.

## Build, Test, and Development Commands
There is no central `Makefile`; validate and deploy per service.

- `kubectl apply --dry-run=client -f apps/n8n/n8n.yaml`: validate a raw manifest locally
- `kubectl apply -f apps/wordpress/wordpress.yaml`: apply a manifest-based service
- `helm upgrade --install traefik traefik/traefik -n core-infra -f core-infra/traefik/values.yaml`: deploy a Helm-managed service
- `helm template vaultwarden <chart> -n apps -f apps/vaultwarden/values.yaml`: render Helm output before applying

Prefer rendering or dry-running changes before touching the cluster.

## Coding Style & Naming Conventions
Use 2-space YAML indentation and keep Kubernetes field order conventional: `apiVersion`, `kind`, `metadata`, `spec`. Keep filenames lowercase and hyphenated, matching the service name, for example `vaultwarden-secret.yaml` or `values-backend.yaml`.

Preserve repository patterns:

- explicit `namespace` on namespaced resources
- `ingressClassName: traefik` for ingress resources
- placeholder values only in tracked secret manifests

## Testing Guidelines
This repo does not include an automated test suite. Validation is configuration-focused:

- run `kubectl apply --dry-run=client -f <file>`
- run `helm template` for every edited `values.yaml`
- check ingress hosts, secret names, `storageClassName`, and referenced PVCs before merge

## Commit & Pull Request Guidelines
Recent commits use short imperative subjects in Title Case, such as `Add AI-Stack`, `Add WordPress`, and `Delete Icons`. Follow the same style and keep each commit scoped to one service or one infrastructure change.

PRs should state the affected namespace and service, note any domain/TLS/secret changes, and call out storage or database impact. Include screenshots only when changing user-visible Homepage configuration.

## Security & Configuration Tips
`.env` files are ignored by Git; keep real credentials there locally. Do not commit live secrets. Tracked `*-secret.yaml` files should remain templates with placeholder values.
