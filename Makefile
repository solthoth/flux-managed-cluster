CLUSTER_NAME ?= stellarus-poc
CONFIG_PATH  ?= clusters/kind/kind-config.yaml

.PHONY: kind-up kind-down kube-check

kind-up:
	CLUSTER_NAME=$(CLUSTER_NAME) CONFIG_PATH=$(CONFIG_PATH) ./scripts/kind-up.sh

kind-down:
	CLUSTER_NAME=$(CLUSTER_NAME) ./scripts/kind-down.sh

kube-check:
	./scripts/kind-check.sh