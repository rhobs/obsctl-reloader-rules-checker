#!/usr/bin/env bash
set -e
set -o pipefail

if [ "$NO_GO_TOOLS_INSTALL" -eq 1 ]; then
    echo "Skipping go tools install as NO_GO_TOOLS_INSTALL variable is set to 1"
    exit 0
fi

cd "$(dirname $BASH_SOURCE)/.."

go install -mod=readonly github.com/bwplotka/bingo@latest

# The following PR has been merged in bingo:
# https://github.com/bwplotka/bingo/pull/142
# Once the new bingo version is released, make sure to append '-t 0' in below commands
unset GOFLAGS
bingo get -v -l github.com/prometheus/prometheus/cmd/promtool@v0.46.0
bingo get -v -l github.com/cloudflare/pint/cmd/pint@v0.44.1