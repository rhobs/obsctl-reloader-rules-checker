#!/usr/bin/env bash
set -e
set -o pipefail

# This script concatenates the yaml files found in a rules directory given by the tenant parameter.

cd "$(dirname $BASH_SOURCE)/.."
dir_path="rules/$1"

if [ "$#" -ne 1 ] || ! [ -d "$dir_path" ]; then
    echo "Usage: $BASH_SOURCE TENANT" >&2
    exit 1
fi

template_path="$dir_path/template.yaml"

# Ensure that we use the binaries from the versions defined in hack/tools/go.mod.
PATH="tmp/bin:${PATH}"

cat <<EOF >| "$template_path"
# THIS FILE IS GENERATED FROM THE RULES FILES IN THE FOLDER
# Do not edit it manually!
# Generate it by running command 'make gen-rules-templates' at the root of your clone.
# Commit this generated file or your MR build will fail.
apiVersion: template.openshift.io/v1
kind: Template
metadata:
  name: all-rules
labels:
  tenant: \${TENANT}
parameters:
  - name: TENANT
    value: $1
objects: []
EOF

find rules/hypershift-platform -type f -name '*.yaml' | sort | while read rules_path; do
    if [ $(yq .kind "$rules_path") = PrometheusRule ]; then
        yq -i ".objects += $(cat "$rules_path" | yq 'to_json(0)' | sed 's/\\n/\n/g')" "$template_path"
        yq -i '.objects[-1].metadata.name = "${TENANT}-" + .objects[-1].metadata.name' "$template_path"
    fi
done