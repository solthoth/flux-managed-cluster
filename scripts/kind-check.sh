#!/usr/bin/env bash
set -euo pipefail

echo ">> kubectl context:"
kubectl config current-context

echo ">> cluster-info:"
kubectl cluster-info

echo ">> nodes:"
kubectl get nodes -o wide

echo ">> system pods:"
kubectl -n kube-system get pods