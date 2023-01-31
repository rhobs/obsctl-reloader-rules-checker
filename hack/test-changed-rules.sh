#!/usr/bin/env bash
set -e
set -o pipefail

cd "$(dirname $BASH_SOURCE)/.."

for test_path in `git status -s | sed 's/^...//g'`; do
    if echo "$test_path" | grep -q '^test/rules/.*\.yaml$'; then
        echo ">> running $test_path <<"
        hack/test-rule.sh "$test_path"
    fi
done