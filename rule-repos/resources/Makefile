SHELL=/usr/bin/env bash -o pipefail

TAG?=$(shell git rev-parse --short HEAD)
VERSION=$(shell cat VERSION | tr -d " \t\n\r")

NO_INSTALL ?= 0
export NO_INSTALL

GOOS?=$(shell go env GOOS)
GOARCH?=$(shell go env GOARCH)
GO111MODULE?=auto
GOPROXY?=http://proxy.golang.org
export GO111MODULE
export GOPROXY

TOOLS_DIR ?= $(shell pwd)/tmp/bin
TOOLS_BIN=$(TOOLS_DIR)/yq $(TOOLS_DIR)/promtool

.PHONY: all
all: clean gen-rules-templates check-rules test-rules yaml-lint

.PHONY: test
test: check-rules test-rules yaml-lint check-rules-templates-are-committed

.PHONY: clean
clean:
	rm -rf tmp

.PHONY: check-rules
check-rules: get-tooling
	hack/check-rules.sh | tee "tmp/$@.out"

.PHONY: test-rules
test-rules: get-tooling
	hack/test-rules.sh | tee "tmp/$@.out"

.PHONY: test-changed-rules
test-changed-rules: get-tooling
	hack/test-changed-rules.sh | tee "tmp/$@.out"

.PHONY: gen-rules-templates
gen-rules-templates: get-tooling
	hack/gen-rules-template.sh hypershift-platform

.PHONY: check-rules-templates-are-committed
check-rules-templates-are-committed: gen-rules-templates
	@! (git status -s | grep -q 'template\.yaml$$') || (echo 'Some generated templates are not committed:'; git status; exit 1)

.PHONY: get-tooling
get-tooling: $(TOOLS_BIN)

$(TOOLS_DIR):
	mkdir -p $(TOOLS_DIR)


$(TOOLS_BIN): $(TOOLS_DIR)
	@echo Installing tools from hack/tools.go
	@hack/install-tools.sh

.PHONY: yaml-lint
yaml-lint:
	@echo Linting yaml files in rules/ and test/
	hack/yaml-lint.sh