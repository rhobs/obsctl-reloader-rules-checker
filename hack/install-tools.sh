#!/usr/bin/env bash
set -e
set -o pipefail

if [ "$NO_INSTALL" -eq 1 ]; then
    echo "Skipping install as NO_INSTALL variable is set to 1"
    exit 0
fi

cd "$(dirname $BASH_SOURCE)/.."
bin_path="$PWD/tmp/bin"

mkdir -p "$bin_path"

cd hack/tools
go list -mod=mod -tags tools -f '{{ range .Imports }}{{ printf "%s\n" .}}{{end}}' ./ | xargs -tI % go build -mod=mod -o "$bin_path" %