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
├── fluxcd/                        # Flux bootstrap configuration
│   ├── base/                      # Shared Flux resources (GitRepositories, Kustomizations)
│   └── overlays/
│       ├── kind/
│       │   ├── kustomization.yaml # Patches base resources for kind
│       │   ├── argocd.yaml        # kind-specific ArgoCD Kustomization patch
│       │   ├── apps.yaml          # kind-specific apps Kustomization patch
│       │   └── flux-system/       # Flux controller manifests + GitRepository/Kustomization bootstrap
│       ├── aws/
│       └── azure/
│
├── argocd/                        # ArgoCD installation + cluster config
│   ├── base/                      # (reserved for shared ArgoCD config)
│   └── overlays/
│       ├── kind/
│       │   ├── kustomization.yaml
│       │   └── argocd/
│       │       ├── namespace.yaml # argocd namespace
│       │       ├── install.yaml   # ArgoCD install manifests
│       │       └── project.yaml   # ArgoCD AppProjects for this cluster
│       ├── aws/
│       └── azure/
│
├── apps/                          # Application sources registered with Flux
│   ├── base/                      # GitRepository definitions (one per app)
│   └── overlays/
│       ├── kind/                  # Kustomization CRs pointing into each app repo
│       ├── aws/
│       └── azure/
│
├── clusters/                      # Cluster-level tooling configuration
│   └── kind/
│       └── kind-config.yaml
│
└── scripts/                       # Helper scripts (kind-up, kind-down, etc.)
```

### Base + Overlays Pattern

Each top-level component (`fluxcd/`, `argocd/`, `apps/`) follows the same Kustomize layout:

- **`base/`** — environment-agnostic resource definitions shared across all targets
- **`overlays/<env>/`** — environment-specific patches and additions that extend the base

This avoids duplicating manifests across environments while still allowing per-environment customization.

---

## Adding a New Application

Applications are split across two areas: this repo registers the source and installs any cluster-level ArgoCD config; the app repo itself provides the ArgoCD `Application` manifest.

### In this repo

**1. Register the Git source** — add a `GitRepository` to [apps/base/](apps/base/):

```yaml
# apps/base/my-app.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/solthoth/my-app.git
  ref:
    branch: main
```

**2. Add a Kustomization** — add a Flux `Kustomization` to the relevant overlay (e.g. [apps/overlays/kind/](apps/overlays/kind/)) that points to where the ArgoCD `Application` manifest lives in the app repo:

```yaml
# apps/overlays/kind/my-app.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 1m
  path: ./deploy/argocd/overlays/kind
  prune: true
  sourceRef:
    kind: GitRepository
    name: my-app
```

**3. Reference both files** in the respective `kustomization.yaml` files (`apps/base/kustomization.yaml` and `apps/overlays/kind/kustomization.yaml`).

**4. Create an ArgoCD AppProject** (if the app references a non-`default` project) — add an `AppProject` to [argocd/overlays/kind/argocd/project.yaml](argocd/overlays/kind/argocd/project.yaml). Flux applies this via the `argocd` Kustomization, so projects are always in place before apps sync.

### In the app repo

The app repo's ArgoCD `Application` manifest must include `spec.destination.server` — ArgoCD requires an explicit cluster target:

```yaml
spec:
  destination:
    namespace: my-app-namespace
    server: https://kubernetes.default.svc   # required for in-cluster deployments
  project: kind-cluster
```

---

## Troubleshooting

### Flux CRs missing after bootstrap

`kubectl apply -k fluxcd/overlays/kind/flux-system` applies CRDs and custom resources in a single pass. If the CRDs aren't fully established before the custom resources are processed, the `GitRepository` and `Kustomization` objects may silently fail to create.

**Check:** `kubectl get gitrepositories,kustomizations -n flux-system`

If nothing is returned, re-apply the sync resources directly:

```zsh
kubectl apply -f fluxcd/overlays/kind/flux-system/gotk-sync.yaml
```

### ArgoCD app shows `InvalidSpecError`

Two common causes:

| Error | Fix |
|---|---|
| `project "X" does not exist` | Add an `AppProject` named `X` to `argocd/overlays/<env>/argocd/project.yaml` |
| `Destination server missing from app spec` | Add `spec.destination.server: https://kubernetes.default.svc` to the app's `Application` manifest in the app repo |

---

## Supported Environments

| Environment | Overlay path |
|---|---|
| kind (local) | `fluxcd/overlays/kind/` |
| AWS | `fluxcd/overlays/aws/` |
| Azure | `fluxcd/overlays/azure/` |
