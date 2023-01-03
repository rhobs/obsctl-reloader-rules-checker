#!/usr/bin/env bash
set -e
set -o pipefail

# This script concatenates the yaml files found in a rules directory given by the tenant parameter.

# Ensure that we use the binaries from the versions defined in hack/tools/go.mod.
PATH="$(pwd)/tmp/bin:${PATH}"

root_path="$(dirname $BASH_SOURCE)/.."
dir_path="$root_path/rules/$1"

if [ "$#" -ne 1 ] || ! [ -d "$dir_path" ]; then
    echo "Usage: $BASH_SOURCE TENANT" >&2
    exit 1
fi

template_path="$dir_path/template.yaml"

cat <<EOF >| "$template_path"
# THIS FILE IS GENERATED FROM THE OTHER FILES IN THE FOLDER
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

for file_name in `ls "$dir_path" | grep '\.yaml$' | grep -v '^template\.yaml$'`; do
    yq -i ".objects += $(cat "$dir_path/$file_name" | yq 'to_json(0)' | sed 's/\\n/\n/g')" "$template_path"
    yq -i '.objects[-1].metadata.name = "${TENANT}-" + .objects[-1].metadata.name' "$template_path"
done