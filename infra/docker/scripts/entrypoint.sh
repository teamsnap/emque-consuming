#!/usr/bin/env bash

set -e

cp infra/docker/scripts/.bashrc ~/.bashrc

### Ruby Entrypoint
######################################################################################
#printf "\033[96mENTRYPOINT: Start bundle install...\033[0m\n"
#bundle check || bundle install
#
#printf "\033[96mENTRYPOINT: Complete\033[0m\n"

exec "$@"
