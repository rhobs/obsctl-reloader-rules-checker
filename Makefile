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
all: clean test-rules

.PHONY: clean
clean:
	rm -rf tmp

.PHONY: get-rules
get-rules:
	mkdir -p tmp/rules
	rm -f tmp/rules.yaml
	hack/find-rules.sh | $(GOJSONTOYAML_BIN) > tmp/rules.yaml

.PHONY: check-rules
check-rules: get-rules
	rm -f tmp/"$@".out
	@$(PROMTOOL_BIN) check rules tmp/rules.yaml | tee "tmp/$@.out"

.PHONY: test-rules
test-rules: check-tooling check-rules
	hack/test-rules.sh | tee "tmp/$@.out"

.PHONY: check-tooling
check-tooling: $(TOOLING)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(TOOLING): $(BIN_DIR)
	@echo Installing tools from hack/tools.go
	@cd hack/tools && go list -mod=mod -tags tools -f '{{ range .Imports }}{{ printf "%s\n" .}}{{end}}' ./ | xargs -tI % go build -mod=mod -o $(BIN_DIR) %
