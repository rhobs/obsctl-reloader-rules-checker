#!/usr/bin/env bash
set -e
set -o pipefail

root_path="$(dirname $BASH_SOURCE)/.."

# Ensure that we use the binaries from the versions defined in hack/tools/go.mod.
PATH="tmp/bin:${PATH}"

playground_path=tmp/check-rules
mkdir -p "$playground_path"

for rules_path in rules/*/*.yaml; do
    if [ $(yq .kind "$rules_path") = PrometheusRule ]; then
        echo ">> checking $rules_path <<"
        name="$(yq .metadata.name "$rules_path")"
        name_pattern='[a-z0-9]\([-a-z0-9]*[a-z0-9]\)\?'
        if echo "$name" | grep -vq "^$name_pattern$"; then
            echo "Invalid .metadata.name attribute. Value is '$name', this does not match pattern '$name_pattern'."
            exit 1
        fi

        if yq '.spec.groups[] | has("interval")' "$rules_path" | grep -qF false; then
            echo "Attribute .spec.groups[].interval is missing for some groups"
            exit 1
        fi

        rm -fr "$playground_path"/*
        yq .spec "$rules_path" >| "$playground_path/rules.yaml"
        promtool check rules "$playground_path/rules.yaml"
    fi
done