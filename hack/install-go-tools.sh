#!/usr/bin/env bash
set -e
set -o pipefail

if [ "$NO_GO_TOOLS_INSTALL" -eq 1 ]; then
    echo "Skipping go tools install as NO_GO_TOOLS_INSTALL variable is set to 1"
    exit 0
fi

cd "$(dirname $BASH_SOURCE)/.."

# System info in lower case to avoid issues.
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m | tr '[:upper:]' '[:lower:]')
OS_ARCH="${OS}-${ARCH}"

PROMETHEUS_VERSION="v2.48.0"

TMPDIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'prometheus')
PROMETHEUS_DEST="$(go env GOPATH)/bin"
RELEASE_INFO=$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/tags/$PROMETHEUS_VERSION)
FILENAME=$(echo -E "$RELEASE_INFO" | jq -r --arg os_arch "$OS_ARCH" '.assets[] | select(.name | contains($os_arch)) | .name')
FILENAME_WITHOUT_EXTENSION="${FILENAME%.*.*}"
DOWNLOAD_URL=$(echo -E "$RELEASE_INFO" | jq -r --arg os_arch "$OS_ARCH" '.assets[] | select(.name | contains($os_arch)) | .browser_download_url')
(cd "$TMPDIR" && wget "$DOWNLOAD_URL" && tar -xzf "$FILENAME" && mv "$FILENAME_WITHOUT_EXTENSION"/promtool ${PROMETHEUS_DEST})
rm -rf "$TMPDIR"

go install -mod=readonly github.com/bwplotka/bingo@latest

# The following PR has been merged in bingo:
# https://github.com/bwplotka/bingo/pull/142
# Once the new bingo version is released, make sure to append '-t 0' in below commands
unset GOFLAGS
bingo get -v -l github.com/cloudflare/pint/cmd/pint@v0.44.1
go install github.com/prometheus-operator/prometheus-operator/cmd/po-lint
