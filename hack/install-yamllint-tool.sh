#!/usr/bin/env bash
set -e

pip3 install yamllint==1.32.0 || {
    echo "Unable to install 'yamllint' through 'pip3'; maybe sure 'pip3' is installed." 
}