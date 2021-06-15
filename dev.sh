#!/bin/bash

set -Eeuo pipefail

if ! oc whoami &>/dev/null; then
  echo "Not connected to OpenShift!"
  exit 1
fi

export THREESCALE_TOKEN="$(oc get secret system-seed -o go-template --template='{{.data.ADMIN_ACCESS_TOKEN|base64decode}}')"
export ADMIN_PORTAL_HOSTNAME="$(oc get route -l zync.3scale.net/route-to=system-provider -o go-template='{{(index .items 0).spec.host}}')"
export OIDC_ISSUER_ENDPOINT="https://zync:changeme@sso-sso.apps.changeme/auth/realms/3scale"

for f in src/*.sh; do
  . "$f"
done

# TODO