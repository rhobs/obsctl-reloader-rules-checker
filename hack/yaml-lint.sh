#!/bin/bash
set -e
set -o pipefail

cd "$(dirname $BASH_SOURCE)/.."

for file in "./**/*.yaml"; do
   yamllint $file
done
