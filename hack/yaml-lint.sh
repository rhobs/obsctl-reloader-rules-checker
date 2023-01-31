#!/bin/bash
set -e
set -o pipefail

root_path="$(dirname $BASH_SOURCE)/.."
rules_path="$root_path/rules/"
test_path="$root_path/test/"

for file in "$rules_path*/*.yaml" "$test_path*/*/*.yaml"; do 
   yamllint $file
done

