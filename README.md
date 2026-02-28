# Flux Managed Cluster

A GitOps-driven cluster template that uses **FluxCD** as the cluster operator to bootstrap and manage **ArgoCD**, which in turn handles application deployments. Supports multiple target environments (kind, AWS, Azure) through a shared base + overlay pattern.

---

## How It Works

```
GitHub Repo
    │
    ▼
FluxCD (cluster operator)
    ├── Installs itself      → fluxcd/overlays/<env>/
    ├── Installs ArgoCD      → argocd/overlays/<env>/
    └── Deploys app sources  → apps/overlays/<env>/
                                    │
                                    ▼
                              ArgoCD (app operator)
                                    └── Deploys applications
```

Flux watches this repository and reconciles all resources automatically. Any change pushed to `main` is applied to the cluster within minutes.

---

## Prerequisites

| Tool | Purpose |
|---|---|
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | Container runtime |
| [kind](https://kind.sigs.k8s.io/) | Local Kubernetes cluster |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | Kubernetes CLI |
| [kustomize](https://kustomize.io/) | Manifest templating |
| [flux](https://fluxcd.io/flux/installation/) | FluxCD CLI |

### Install on macOS (Homebrew)

```zsh
brew install kind kubectl kustomize
brew install --cask docker-desktop
brew install fluxcd/tap/flux
```

---

## Getting Started (kind)

### 1. Start the cluster

```zsh
make kind-up
```

The kind cluster configuration is at [clusters/kind/kind-config.yaml](clusters/kind/kind-config.yaml).

### 2. Bootstrap Flux

```zsh
kubectl apply -k fluxcd/overlays/kind/flux-system
```

This installs the Flux controllers and creates the `GitRepository` and `Kustomization` resources that point back at this repo. From this point Flux manages everything else automatically.

### 3. Verify Flux is reconciling

```zsh
flux get kustomizations
```

All kustomizations should eventually show `True` in the `READY` column. Flux will install ArgoCD and register any configured app sources.

### 4. Access ArgoCD

Set up port forwarding:

```zsh
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Retrieve the initial admin password:

```zsh
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

Open [https://localhost:8080](https://localhost:8080) and log in with username `admin`.

---

## Repository Structure

```text
flux-managed-cluster/
│
├── fluxcd/                   # Flux bootstrap configuration
│   ├── base/                 # Shared Flux resources (GitRepositories, Kustomizations)
│   └── overlays/
│       ├── kind/             # kind-specific Flux config
│       ├── aws/
│       └── azure/
│
├── argocd/                   # ArgoCD installation manifests
│   ├── base/                 # (reserved for shared ArgoCD config)
│   └── overlays/
│       ├── kind/             # kind-specific ArgoCD install
│       ├── aws/
│       └── azure/
│
├── apps/                     # Application sources managed by Flux
│   ├── base/                 # GitRepository definitions for each app
│   └── overlays/
│       └── kind/             # kind-specific Kustomizations pointing to app repos
│
└── clusters/                 # Cluster-level configuration (e.g. kind-config.yaml)
    └── kind/
```

### Base + Overlays Pattern

Each top-level component (`fluxcd/`, `argocd/`, `apps/`) follows the same Kustomize layout:

- **`base/`** — environment-agnostic resource definitions shared across all targets
- **`overlays/<env>/`** — environment-specific patches and additions that extend the base

This avoids duplicating manifests across environments while still allowing per-environment customization.

---

## Adding a New Application

1. Add a `GitRepository` source for the app in [apps/base/](apps/base/).
2. Add a `Kustomization` CR in the relevant overlay (e.g. [apps/overlays/kind/](apps/overlays/kind/)) pointing to the deployment path in the app's repo.
3. Reference the new files in the respective `kustomization.yaml`.

Flux will pick up the changes and apply them within the next reconciliation interval.

---

## Supported Environments

| Environment | Overlay path |
|---|---|
| kind (local) | `fluxcd/overlays/kind/` |
| AWS | `fluxcd/overlays/aws/` |
| Azure | `fluxcd/overlays/azure/` |
