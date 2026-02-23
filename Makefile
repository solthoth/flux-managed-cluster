CLUSTER_NAME ?= solthoth-poc
CONFIG_PATH  ?= clusters/kind/kind-config.yaml

.PHONY: kind-up kind-down kind-check

kind-up:
	CLUSTER_NAME=$(CLUSTER_NAME) CONFIG_PATH=$(CONFIG_PATH) ./scripts/kind-up.sh

kind-down:
	CLUSTER_NAME=$(CLUSTER_NAME) ./scripts/kind-down.sh

kind-check:
	./scripts/kind-check.sh