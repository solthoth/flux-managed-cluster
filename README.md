# Flux Managed Cluster

This repository creates a kind cluster and installs flux-cd to manage GitRepositories.

# Getting Started

## Prerequisites

- Docker Desktop
- kind
- kubectl
- kustomize
- Flux
- Make

### Mac OS Setup

Using homebrew

```zsh
brew install kind kubectl kustomize make
brew install --cask docker-desktop
brew install fluxcd/tap/flux
```

## Starting Up the Cluster

Using the Makefile run the following command:

```zsh
make kind-up
```

The kind cluster configuration is located at `./clusters/kind/kind-config.yaml`.

Once the cluster is up and running, apply the flux-cd configuration using kustomize.

```zsh
kubectl apply -k clusters/kind/flux-system
```

Once FluxCD is up and running, it will automatically install and configure ArgoCD.
In order to access first setup port forward for local access.

```zsh
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Extract the password for local access

```zsh
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

# Project Understanding

FluxCD is acting as the orchestrator to deploy changes from remote repositories. `clusters/kind/flux-system` maintains the configuration of Flux, and reconciles itself in the event of changes.

## Adding Additional Repositories

Within the `clusters/kind` folder is an `apps` folder. Here are the manifests of all applications of type `Kind:GitRepository`. This tells FluxCD to pull the repositories defined in here for aorchestration.