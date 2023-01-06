#!/usr/bin/env bash
set -e
set -o pipefail

root_path="$(dirname $BASH_SOURCE)/.."
cd "$root_path"

# Ensure that we use the binaries from the versions defined in hack/tools/go.mod.
PATH="tmp/bin:${PATH}"

playground_path=tmp/test-rules
mkdir -p "$playground_path"

for test_path in test/rules/*/*.yaml; do
	echo ">> running $test_path <<"
	rm -fr "$playground_path"/*
	cp "$test_path" "$playground_path"
	tenant="$(basename "$(dirname "$test_path")")"
	yq .rule_files "$test_path" | while read rules_files_item; do
		rule_file_name="$(echo "$rules_files_item" | sed 's/^- //g')"
		yq .spec "rules/$tenant/$rule_file_name" >| "$playground_path/$rule_file_name"
	done
	promtool test rules "$playground_path/$(basename "$test_path")"
done