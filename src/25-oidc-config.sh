function oidc_configuration_update () {
    local -n oidc_configuration=$1

    echo "Updating OIDC configuration..." >&2
    threescale_call policy_update PATCH "$(breadcrumb_to_path breadcrumb)/proxy/oidc_configuration.json" "200" $(map_to_curl oidc_configuration)
}
