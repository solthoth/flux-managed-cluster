# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A GitOps cluster template. FluxCD is the cluster operator — it installs ArgoCD, Crossplane, and all infrastructure. ArgoCD then manages application deployments. All changes to `main` are automatically applied to the cluster.

```
FluxCD → installs ArgoCD + Crossplane
ArgoCD → deploys applications
Crossplane → provisions cloud infrastructure (Azure)
```

## Common Commands

### Cluster lifecycle (kind)

```zsh
./scripts/kind-up.sh          # Create kind cluster (name: solthoth-poc)
./scripts/kind-down.sh        # Destroy kind cluster
./scripts/kind-check.sh       # Check cluster status
```

### Bootstrap Flux

```zsh
kubectl apply -k fluxcd/overlays/kind/flux-system
```

If GitRepository/Kustomization objects are missing after bootstrap, re-apply the sync file directly:

```zsh
kubectl apply -f fluxcd/overlays/kind/flux-system/gotk-sync.yaml
```

### Verify reconciliation

```zsh
flux get kustomizations                                        # All Flux Kustomizations + status
flux get kustomizations --watch                               # Watch until all Ready
kubectl get providers -n crossplane-system                    # Crossplane provider health
kubectl get xstoragequeues,storagequeues -A                   # Crossplane composite + managed resources
```

### SOPS: encrypt a new secret

```zsh
kubectl create secret generic azure-sp-creds \
  --namespace=crossplane-system \
  --from-literal=credentials='{"clientId":"...","clientSecret":"...","tenantId":"...","subscriptionId":"...","activeDirectoryEndpointUrl":"https://login.microsoftonline.com","resourceManagerEndpointUrl":"https://management.azure.com/","activeDirectoryGraphResourceId":"https://graph.windows.net/","sqlManagementEndpointUrl":"https://management.core.windows.net:8443/","galleryEndpointUrl":"https://gallery.azure.com/","managementEndpointUrl":"https://management.core.windows.net/"}' \
  --dry-run=client -o yaml \
  | sops --encrypt --input-type=yaml --output-type=yaml --filename-override crossplane/overlays/kind/config/azure-sp.enc.yaml /dev/stdin \
  > crossplane/overlays/kind/config/azure-sp.enc.yaml
```

Create the age secret in the cluster:

```zsh
kubectl create secret generic sops-age --namespace=flux-system --from-file=age.agekey=./age.agekey
```

Or using local key:

```zsh
kubectl create secret generic sops-age --namespace=flux-system --from-file=age.agekey=$HOME/.config/sops/age/keys.txt
```

### Terraform (Azure SP provisioning)

```zsh
cd terraform/azure
terraform init && terraform apply
```

Outputs: `client_id`, `client_secret`, `tenant_id`, `subscription_id`, `resource_group_name`, `location`.

### Validate Kustomize builds locally

```zsh
kustomize build fluxcd/overlays/kind
kustomize build crossplane/overlays/kind/claims
```

### Access ArgoCD

```zsh
kubectl -n argocd port-forward svc/argocd-server 8080:443
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

## Architecture

### Flux Kustomization DAG (kind overlay)

All layers depend on the previous — Flux enforces ordering via `dependsOn`:

```
flux-system (controllers)
  └── flux-managed-cluster (GitRepository + top-level Kustomization)
        └── argocd
        └── apps
        └── crossplane (HelmRelease, waits for CRDs)
              └── crossplane-providers   → crossplane/base/providers/
                    └── crossplane-config → overlays/<env>/config/  (SOPS secret + ProviderConfig)
                          └── crossplane-compositions → crossplane/compositions/
                                └── crossplane-claims → overlays/<env>/claims/
```

### Base + Overlays pattern

Every top-level component (`fluxcd/`, `argocd/`, `apps/`, `crossplane/`) uses:
- **`base/`** — environment-agnostic resources shared across all targets
- **`overlays/<env>/`** — environment-specific patches (`kind`, `aws`, `azure`)

Crossplane `providers/` and `compositions/` are fully shared. Only `config/` and `claims/` are per-environment.

### Crossplane: StorageQueue XR

API group: `platform.solthoth.io`

A single `StorageQueue` claim (namespace-scoped) creates three Azure resources via the Composition:
1. `ResourceGroup` → `<claim-name>-rg`
2. Storage `Account` → `<claim-name>-sa` (Azure name = `spec.parameters.storageAccountName`)
3. Storage `Queue` → `<claim-name>-queue`

The `ProviderConfig` named `default` references the `azure-sp-creds` Secret in `crossplane-system`, which Flux decrypts from `azure-sp.enc.yaml` using SOPS/age.

### SOPS

Encrypted files match: `crossplane/overlays/.*/config/.*\.enc\.yaml$`
Age public key is in `.sops.yaml`. The private key must be loaded into the cluster as the `sops-age` Secret before Flux can decrypt.

## Adding a New Environment

To promote to a new environment (e.g. `aws`):
1. Add `fluxcd/overlays/aws/` with Kustomization patches pointing to the new paths
2. Add `crossplane/overlays/aws/config/` (ProviderConfig + encrypted secret) and `claims/`
3. `crossplane/base/providers/` and `crossplane/compositions/` require no changes — they are shared

## Adding a New Application

1. Add a `GitRepository` to `apps/base/`
2. Add a Flux `Kustomization` to `apps/overlays/<env>/` pointing to the ArgoCD `Application` manifest in the app repo
3. Register both in their respective `kustomization.yaml` files
4. If the app uses a non-`default` ArgoCD project, add an `AppProject` to `argocd/overlays/<env>/argocd/project.yaml`

The app repo's `Application` manifest must set `spec.destination.server: https://kubernetes.default.svc`.
