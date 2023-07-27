# Flags you can override before invoking the Makefile to control
# which tools you want to install.
NO_GO_TOOLS_INSTALL ?= 0
export NO_GO_TOOLS_INSTALL

GO_TOOLS_BINS=$(GOPATH)/bin/promtool
CODE_BIN=bin/obsctl-reloader-rules-checker

# Runtime CLI to use for building and pushing images
CONTAINER_ENGINE ?= $(shell command -v podman 2>/dev/null || echo docker)
LOCAL_DOCKER_IMG=obsctl-reloader-rules-checker:latest

.PHONY: default
default: local-checks

.PHONY: yamllint-tool
yamllint-tool:
	@./hack/install-yamllint-tool.sh

.PHONY: tidy
tidy:
	@echo "-> Updating go.mod and go.sum from the imports..."
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

bin:
	mkdir bin

$(GO_TOOLS_BINS):
	@echo "-> Building go tools..."
	./hack/install-go-tools.sh

.PHONY: go-tools
go-tools: $(GO_TOOLS_BINS)

$(CODE_BIN): main.go
	@echo "-> Building code..."
	go build -mod=mod -o $(CODE_BIN)

.PHONY: build
build: bin $(CODE_BIN) go-tools

.PHONY: clean
clean:
	rm -rf .bingo bin dist

.PHONY: docker-build
docker-build:
	@echo "-> Building docker image..."
	$(CONTAINER_ENGINE) build . -t $(LOCAL_DOCKER_IMG)

.PHONY: local-checks
local-checks: format go-lint build

.PHONY: pr-checks
pr-checks: no-format-change lint docker-build