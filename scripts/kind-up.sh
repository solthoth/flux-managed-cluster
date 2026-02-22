#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-stellarus-poc}"
CONFIG_PATH="${CONFIG_PATH:-clusters/kind/kind-config.yaml}"

echo ">> Creating kind cluster: ${CLUSTER_NAME}"
kind create cluster --name "${CLUSTER_NAME}" --config "${CONFIG_PATH}"

echo ">> Setting kubectl context"
kubectl config use-context "kind-${CLUSTER_NAME}"

echo ">> Waiting for nodes to be ready"
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo ">> Cluster is up"
kubectl get nodes -o wide