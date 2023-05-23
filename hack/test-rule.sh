#!/usr/bin/env bash
set -e
set -o pipefail

cd "$(dirname $BASH_SOURCE)/.."

if [ $# -ne 1 ] || ! [ -f "$1" ]; then
    echo "Usage: $BASH_SOURCE TEST_PATH"
    echo
    echo "With TEST_PATH being a .yaml file in following location:"
    echo "$PWD/test/rules"
    echo
    echo "Make sure 'yq' and 'promtool' are installed prior running this command."
    echo "You can install those tools running 'make get-tooling' from this directory:"
    echo "$PWD"
    exit 1
fi

# Ensure that we use the binaries from the versions defined in hack/tools/go.mod.
PATH="tmp/bin:${PATH}"

test_path=$1
playground_path=tmp/test-rules

rm -fr "$playground_path"
mkdir -p "$playground_path"

cp "$test_path" "$playground_path"
rules_folder_name="$(basename "$(dirname "$test_path")")"
yq .rule_files "$test_path" | while read rules_files_item; do
    rule_file_name="$(echo "$rules_files_item" | sed 's/^- //g')"
    yq .spec "rules/$rules_folder_name/$rule_file_name" >| "$playground_path/$rule_file_name"
done

promtool test rules "$playground_path/$(basename "$test_path")"