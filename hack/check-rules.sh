#!/usr/bin/env bash
set -e
set -o pipefail

name_pattern='[a-z0-9]\([-a-z0-9]*[a-z0-9]\)\?'

cd "$(dirname $BASH_SOURCE)/.."

# Ensure that we use the binaries from the versions defined in hack/tools/go.mod.
PATH="tmp/bin:${PATH}"

playground_path=tmp/check-rules
mkdir -p "$playground_path"

processed_groups_refs=

for rules_path in rules/*/*.yaml; do
    if [ $(yq .kind "$rules_path") = PrometheusRule ]; then
        echo ">> checking $rules_path <<"
        name="$(yq .metadata.name "$rules_path")"
        tenant="$(basename "$(dirname "$rules_path")")"

        if echo "$name" | grep -vq "^$name_pattern$"; then
            echo "Invalid .metadata.name attribute. Value is '$name', this does not match pattern '$name_pattern'."
            exit 1
        fi

        for group_name in `yq '.spec.groups[].name' "$rules_path"`; do
            group_ref="$tenant $group_name"
            if echo "$processed_groups_refs" | grep -qF "$group_ref"; then
                echo "Invalid .spec.groups[].name. Value is '$group_name', this group is already used in '$tenant' tenant."
                exit 1
            fi
            processed_groups_refs="$processed_groups_refs\n$group_ref"
        done

        if yq '.spec.groups[] | has("interval")' "$rules_path" | grep -qF false; then
            echo "Attribute .spec.groups[].interval is missing for some groups"
            exit 1
        fi

        rm -fr "$playground_path"/*
        yq .spec "$rules_path" >| "$playground_path/rules.yaml"
        promtool check rules "$playground_path/rules.yaml"
    fi
done