# note: call scripts from /scripts

.PHONY: default build build-image test stop push apply deploy release release-all manifest push

OS ?= linux
ARCH ?= ???
ALL_ARCH ?= arm64 arm amd64

BUILDER ?= reloader-builder-${ARCH}
BINARY ?= Reloader
DOCKER_IMAGE ?= stakater/reloader

# Default value "dev"
VERSION ?= 0.0.1

REPOSITORY_GENERIC = ${DOCKER_IMAGE}:${VERSION}
REPOSITORY_ARCH = ${DOCKER_IMAGE}:v${VERSION}-${ARCH}
BUILD=

GOCMD = go
GOFLAGS ?= $(GOFLAGS:)
LDFLAGS =

default: build test

install:
	"$(GOCMD)" mod download

run:
	go run ./main.go

build:
	"$(GOCMD)" build ${GOFLAGS} ${LDFLAGS} -o "${BINARY}"

build-image:
	docker buildx build --platform ${OS}/${ARCH} --build-arg GOARCH=$(ARCH) -t "${REPOSITORY_ARCH}" --load -f Dockerfile .

push:
	docker push ${REPOSITORY_ARCH}

release: build-image push manifest

release-all:
	-rm -rf ~/.docker/manifests/*
	# Make arch-specific release
	@for arch in $(ALL_ARCH) ; do \
		echo Make release: $$arch ; \
		make release ARCH=$$arch ; \
	done

	set -e
	docker manifest push --purge $(REPOSITORY_GENERIC)

manifest:
	set -e
	docker manifest create -a $(REPOSITORY_GENERIC) $(REPOSITORY_ARCH)
	docker manifest annotate --arch $(ARCH) $(REPOSITORY_GENERIC)  $(REPOSITORY_ARCH)

test:
	"$(GOCMD)" test -timeout 1800s -v ./...

stop:
	@docker stop "${BINARY}"

apply:
	kubectl apply -f deployments/manifests/ -n temp-reloader

deploy: binary-image push apply

# Bump Chart
bump-chart: 
	sed -i "s/^version:.*/version: v$(VERSION)/" deployments/kubernetes/chart/reloader/Chart.yaml
	sed -i "s/^appVersion:.*/appVersion: v$(VERSION)/" deployments/kubernetes/chart/reloader/Chart.yaml
	sed -i "s/tag:.*/tag: v$(VERSION)/" deployments/kubernetes/chart/reloader/values.yaml
	sed -i "s/version:.*/version: v$(VERSION)/" deployments/kubernetes/chart/reloader/values.yaml
