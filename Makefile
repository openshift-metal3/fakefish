REGISTRY ?= quay.io
IMAGE_NAMESPACE ?= mavazque
IMAGE_NAME ?= fakefish
IMAGE_URL ?= $(REGISTRY)/$(IMAGE_NAMESPACE)/$(IMAGE_NAME)
TAG ?= latest

.PHONY: build-dell build-custom pre-reqs

default: pre-reqs build-custom

build-dell:
	podman build . -f dell_scripts/Containerfile -t ${IMAGE_URL}:${TAG}

build-custom: pre-reqs
	podman build . -f custom_scripts/Containerfile -t ${IMAGE_URL}:${TAG}

.SILENT:
pre-reqs:
	if [ $(shell find custom_scripts/ -name "*.sh" | grep -Ec "mountcd.sh|poweroff.sh|poweron.sh|unmountcd.sh|bootfromcdonce.sh") -ne 5 ];then echo 'Missing custom scripts or bad naming';exit 1;fi
