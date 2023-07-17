# Flags you can override before invoking the Makefile to control
# which tools you want to install.
NO_GO_TOOLS_BUILD ?= 0
export NO_GO_TOOLS_BUILD

BUILDFLAGS ?=
unexport GOFLAGS

BIN_DIR ?= $(shell pwd)/bin
TOOLS_BIN=$(BIN_DIR)/promtool

# Runtime CLI to use for building and pushing images
CONTAINER_ENGINE ?= $(shell command -v docker 2>/dev/null || command -v podman 2>/dev/null)
IMG ?= obsctl-reloader-rules-checker:latest

.PHONY: default
default: local-checks

.PHONY: yamllint-tool
yamllint-tool:
	@./hack/install-yamllint-tool.sh

.PHONY: tidy
tidy:
	@echo "-> Updating go.mod and go.sum from the imports..."
	cd hack/go-tools && go mod tidy
	go mod tidy

.PHONY: fmt
fmt:
	@echo "-> Formatting the go code..."
	go fmt ./...

.PHONY: format
format: tidy fmt

.PHONY: no-format-change
no-format-change: format
	@echo "-> Making sure that formatting operations did not change any file..."
	git diff --exit-code .

.PHONY: go-lint
go-lint:
	@echo "-> Linting go code..."
	golangci-lint run

.PHONY: yaml-lint
yaml-lint:
	@echo "-> Linting YAML files..."
	yamllint .

.PHONY: lint
lint: go-lint yaml-lint

$(BIN_DIR):
	mkdir $(BIN_DIR)

$(TOOLS_BIN): $(BIN_DIR)
	@echo "-> Building go tools from hack/tools.go..."
	./hack/build-go-tools.sh

.PHONY: go-tools
go-tools: $(TOOLS_BIN)

.PHONY: build
build: go-tools
	@echo "-> Building code..."
	go build -mod=mod -o $(BIN_DIR)/obsctl-reloader-rules-checker

.PHONY: clean
clean:
	rm -rf bin

.PHONY: docker-build
docker-build:
	@echo "-> Building docker image..."
	${CONTAINER_ENGINE} build . -t ${IMG}

.PHONY: local-checks
local-checks: format go-lint build

.PHONY: pr-checks
pr-checks: no-format-change lint docker-build