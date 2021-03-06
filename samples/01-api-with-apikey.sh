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
## Service creation
##
declare -A service_def=( ["system_name"]="$SERVICE_NAME" ["name"]="Echo API" ["description"]="Echo API" ["deployment_option"]="hosted" ["backend_version"]="1" )
apply service present service_def
service_id=$last_object_id

##
## Backend creation
##
declare -A backend_def=( ["system_name"]="$SERVICE_NAME" ["name"]="Echo API" ["private_endpoint"]="https://echo-api.3scale.net" )
apply backend present backend_def
backend_id=$last_object_id

##
## Backend method creation
##

# Find the "hits" metric so that we can create the methods under it
breadcrumb=( backend_apis $backend_id )
hits_metric_id="$(metric_list | id_of_external_id_with_prefix "system_name" "hits")"

# Create one method
breadcrumb=( backend_apis $backend_id metrics $hits_metric_id )
declare -A method_def=( ["system_name"]="say_hello" ["friendly_name"]="sayHello" ["unit"]="hits" )
apply method present method_def
method_id=$last_object_id

# Create one mapping rule
breadcrumb=( backend_apis $backend_id )
delete_all "mapping_rule"
declare -A mapping_rule_def=( ["http_method"]="GET" ["pattern"]="/" ["delta"]="1" ["metric_id"]="$method_id" )
mapping_rule_create mapping_rule_def

##
## Proxy configuration
##
breadcrumb=( services $service_id )
declare -A proxy_def=( ["credentials_location"]="headers" ["auth_user_key"]="X-APIKey" )
proxy_update proxy_def
proxy="$(get_result proxy_update | cleanup_item)"

# Unless specified in the proxy definition, the endpoints are generated by 3scale
staging_endpoint="$(echo "$proxy" | jq -r .sandbox_endpoint)"
echo "Staging endpoint is: $staging_endpoint"
production_endpoint="$(echo "$proxy" | jq -r .endpoint)"
echo "Production endpoint is: $production_endpoint"

##
## Link the Backend to the Service
##
breadcrumb=( services $service_id )
declare -A backend_usage_def=( ["backend_id"]="$backend_id" ["path"]="/" )
apply backend_usage present backend_usage_def

##
## Update the policy chain
##
breadcrumb=( services $service_id )
policies="$(policy_list | remove_policy 'cors' | jq '. += [ {"name": "cors", "version": "builtin", "configuration": {"allow_credentials": true}, "enabled": true} ]')"
policy_update "$policies"

##
## Create one application plan
##
breadcrumb=( services $service_id )
declare -A application_plan_def=( ["system_name"]="test" ["name"]="Test plan" )
apply application_plan present application_plan_def
application_plan_id=$last_object_id

# Create Limits for the sayHello method
breadcrumb=( application_plans $application_plan_id metrics $method_id )
declare -A limit_def=( ["period"]="minute" ["value"]="5" )
apply limit present limit_def
declare -A limit_def=( ["period"]="day" ["value"]="100" )
apply limit present limit_def

# Re-Create Pricing Rules for the sayHello method
breadcrumb=( application_plans $application_plan_id metrics $method_id )
delete_all "pricing_rule"
declare -A pricing_rule_def=( ["min"]="1" ["max"]="10" ["cost_per_unit"]="1.0" )
pricing_rule_create pricing_rule_def
declare -A pricing_rule_def=( ["min"]="11" ["max"]="100" ["cost_per_unit"]="0.9" )
pricing_rule_create pricing_rule_def
declare -A pricing_rule_def=( ["min"]="101" ["max"]="1000" ["cost_per_unit"]="0.8" )
pricing_rule_create pricing_rule_def
declare -A pricing_rule_def=( ["min"]="1001" ["max"]="" ["cost_per_unit"]="0.75" )
pricing_rule_create pricing_rule_def

##
## Create a test application
##

# The application can be created in the default first account (aka the "Developer" account)
account_id="$(find_first_account | jq '.id')"

# The user_key is an external identifier for the application. To achieve
# idempotency, we need to generate one by ourself.
#
# The application name, service system_name and admin access token (secret) are
# hashed together to produce a stable but unguessable identifier.
application_name="Test app"
user_key="$(echo -n "${application_name}${SERVICE_NAME}${THREESCALE_TOKEN}" | sha1sum | cut -d " " -f1)"

breadcrumb=( accounts $account_id )
declare -A application_def=( ["plan_id"]="$application_plan_id" ["name"]="$application_name" ["description"]="used for internal testing" ["user_key"]="$user_key" )
apply application_apikey present application_def
application_id=$last_object_id

##
## Smoke tests
##

echo "Waiting 5 seconds before running tests on the staging environment..."
sleep 5

if ! curl -sfk $staging_endpoint/hello -H "X-APIKey: $user_key" > /dev/null; then
  echo "Smoke test failed!"
  exit 1
fi

##
## Promotion to production
##
breadcrumb=( services $service_id )
staging_version="$(proxy_version 'sandbox')"
echo "Proxy version in staging: $staging_version"
production_version="$(proxy_version 'production' || echo 'none')"
echo "Proxy version in production: $production_version"

if [ "$staging_version" != "$production_version" ]; then
  proxy_promote sandbox "$staging_version"
fi

##
## Final tests
##

while ! curl -sfk $production_endpoint/hello -H "X-APIKey: $user_key" &> /dev/null; do
  echo "Production API is not yet ready..."
  sleep 5
done

curl -sfk $production_endpoint/hello -H "X-APIKey: $user_key" --write-out "Production API - HTTP %{http_code}\n" -o /dev/null
