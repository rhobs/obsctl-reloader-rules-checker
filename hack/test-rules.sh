#!/usr/bin/env bash
set -e
set -o pipefail

cd "$(dirname $BASH_SOURCE)/.."

for test_path in test/rules/*/*.yaml; do
	echo ">> running $test_path <<"
	hack/test-rule.sh "$test_path"
done