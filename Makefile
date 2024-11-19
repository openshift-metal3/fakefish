IMAGE_NAME ?= fakefish
ORG        ?= fakefish
REGISTRY   ?= quay.io
IMAGE_URL  ?= $(REGISTRY)/$(ORG)/$(IMAGE_NAME)
AUTHOR     ?= Mario Vazquez <mavazque@redhat.com>
TAG        ?= latest

.PHONY: build-dell build-kubevirt build-supermicro build-hpe-gen9 build-custom pre-reqs

default: pre-reqs build-custom

build-dell:
	podman build . -f dell_scripts/Containerfile -t $(IMAGE_URL):$(TAG) --label org.opencontainers.image.authors"=$(AUTHOR)"

build-kubevirt:
	podman build . -f kubevirt_scripts/Containerfile -t $(IMAGE_URL):$(TAG) --label org.opencontainers.image.authors"=$(AUTHOR)"

build-supermicro:
	podman build . -f supermicro_scripts/Containerfile -t $(IMAGE_URL):$(TAG) --label org.opencontainers.image.authors"=$(AUTHOR)"

build-hpe-gen9:
	podman build . -f hpe-gen9-ilo4-scripts/Containerfile -t $(IMAGE_URL):$(TAG) --label org.opencontainers.image.authors"=$(AUTHOR)"

build-custom: pre-reqs
	podman build . -f custom_scripts/Containerfile -t $(IMAGE_URL):$(TAG) --label org.opencontainers.image.authors"=$(AUTHOR)"

build-kvm_scripts:
	podman build . -f kvm_scripts/Containerfile -t $(IMAGE_URL):$(TAG) --label org.opencontainers.image.authors"=$(AUTHOR)"
	
.SILENT:
pre-reqs:
	if [ $(shell find custom_scripts/ -name "*.sh" | grep -Ec "mountcd.sh|poweroff.sh|poweron.sh|unmountcd.sh|bootfromcdonce.sh") -ne 5 ];then echo 'Missing custom scripts or bad naming';exit 1;fi


