# Repository Guidelines

## Project Structure & Module Organization
This repository stores K3s deployment config by namespace:

- `apps/`: user-facing services such as `vaultwarden`, `n8n`, `homepage`, and `wordpress`
- `core-infra/`: cluster foundations such as `traefik`, `cert-manager`, and `longhorn`
- `database/`: shared data services such as `postgresql` and `mariadb`
- `monitoring/`: observability and uptime tooling

Most service directories contain either `values.yaml` for a Helm release or one or more plain Kubernetes manifests such as `n8n.yaml` and `*-secret.yaml`. `apps/homepage/config/` holds Homepage-specific YAML data files.

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
