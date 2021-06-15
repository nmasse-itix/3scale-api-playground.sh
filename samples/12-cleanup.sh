#!/bin/bash

set -Eeuo pipefail

. 3scale-admin-cli.sh

if [ -z "${THREESCALE_TOKEN:-}" ]; then
    echo "Please set the THREESCALE_TOKEN environment variable!"
    exit 1
fi

if [ -z "${ADMIN_PORTAL_HOSTNAME:-}" ]; then
    echo "Please set the ADMIN_PORTAL_HOSTNAME environment variable!"
    exit 1
fi

if [ -z "${SERVICE_NAME:-}" ]; then
    echo "Please set the SERVICE_NAME environment variable!"
    exit 1
fi

##
## Service deletion
##
declare -A service_def=( ["system_name"]="${SERVICE_NAME}" )
apply service absent service_def

echo "Waiting 5 seconds before deleting the backend..."
sleep 5

##
## Backend deletion
##
declare -A backend_def=( ["system_name"]="${SERVICE_NAME}" )
apply backend absent backend_def
