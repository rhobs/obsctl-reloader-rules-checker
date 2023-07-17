#!/usr/bin/env bash
set -e
set -o pipefail

if [ "$NO_GO_TOOLS_BUILD" -eq 1 ]; then
    echo "Skipping go tools build as NO_GO_TOOLS_BUILD variable is set to 1"
    exit 0
fi

cd "$(dirname $BASH_SOURCE)/.."
bin_path="$PWD/bin"

mkdir -p "$bin_path"

cd hack/go-tools
go list -mod=mod -tags tools -f '{{ range .Imports }}{{ printf "%s\n" .}}{{end}}' ./ | xargs -tI % go build -mod=mod -o "$bin_path" %