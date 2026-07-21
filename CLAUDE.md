# CLAUDE.md

This repo holds declarative deployment config for a single-node **K3s** home server.
Follow the repository guidelines below, and read `docs/INFRASTRUCTURE.md` for full
cluster topology, live service inventory, and the in-progress migration state.

@AGENTS.md

## Working On This Cluster
- The repo does **not** always match the live cluster (layout/domain/namespace migration in progress). Run `kubectl get ...` / `helm list -A` to confirm real state before changing anything.
- No CI/CD — deploy per service with `kubectl apply` (raw manifests) or `helm upgrade --install` (Helm values). Always dry-run / `helm template` first.
- Never write real secrets into tracked `*-secret.yaml` files; they are placeholders synced from Infisical via `*-secret-sync.yaml`.
