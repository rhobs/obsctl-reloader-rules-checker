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
bingo get -v -l -t 0 github.com/prometheus/prometheus/cmd/promtool@v0.46.0
bingo get -v -l -t 0 github.com/cloudflare/pint/cmd/pint@244dfc72999e3d27dbb575dfff9b41d94dc2d750
