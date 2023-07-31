#!/usr/bin/env bash
set -e
set -o pipefail

if [ "$NO_GO_TOOLS_INSTALL" -eq 1 ]; then
    echo "Skipping go tools install as NO_GO_TOOLS_INSTALL variable is set to 1"
    exit 0
fi

cd "$(dirname $BASH_SOURCE)/.."

go install -mod=readonly github.com/bwplotka/bingo@latest

unset GOFLAGS
bingo get -v -l github.com/prometheus/prometheus/cmd/promtool@v0.41.0
bingo get -v -l github.com/cloudflare/pint/cmd/pint@v0.44.1