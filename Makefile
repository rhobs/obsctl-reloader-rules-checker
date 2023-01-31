SHELL=/usr/bin/env bash -o pipefail

TAG?=$(shell git rev-parse --short HEAD)
VERSION=$(shell cat VERSION | tr -d " \t\n\r")

GOOS?=$(shell go env GOOS)
GOARCH?=$(shell go env GOARCH)
GO111MODULE?=auto
GOPROXY?=http://proxy.golang.org
export GO111MODULE
export GOPROXY

BIN_DIR ?= $(shell pwd)/tmp/bin

GOJSONTOYAML_BIN=$(BIN_DIR)/gojsontoyaml
PROMTOOL_BIN=$(BIN_DIR)/promtool
TOOLING=$(GOJSONTOYAML_BIN) $(PROMTOOL_BIN)

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

.PHONY: gen-rules-templates
gen-rules-templates: get-tooling
	hack/gen-rules-template.sh hypershift-platform

.PHONY: check-rules-templates-are-committed
check-rules-templates-are-committed: gen-rules-templates
	@! (git status -s | grep -q 'template\.yaml$$') || (echo 'Some generated templates are not committed:'; git status; exit 1)

.PHONY: get-tooling
get-tooling: $(TOOLING)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(TOOLING): $(BIN_DIR)
	@echo Installing tools from hack/tools.go
	@cd hack/tools && go list -mod=mod -tags tools -f '{{ range .Imports }}{{ printf "%s\n" .}}{{end}}' ./ | xargs -tI % go build -mod=mod -o $(BIN_DIR) %

.PHONY: yaml-lint
yaml-lint:
	@echo Linting yaml files in rules/ and test/
	hack/yaml-lint.sh