#!/usr/bin/env bash
set -e

cd "$(dirname $BASH_SOURCE)/.."

if ! [ -f go.mod ]; then
    mkdir bin
    mv obsctl-reloader-rules-checker bin/
fi