function proxy_update () {
    local -n proxy=$1
    echo "Updating proxy..." >&2
    threescale_call proxy_update PUT "$(breadcrumb_to_path breadcrumb)/proxy.json" "200" $(map_to_curl proxy)
}

function proxy_version () {
    local environment=$1

    echo "Getting proxy version of env $environment..." >&2
    threescale_call proxy_version GET "$(breadcrumb_to_path breadcrumb)/proxy/configs/${environment}/latest.json" "200"
    if [ $? -gt 0 ]; then
        return $?
    fi

    get_result proxy_version | cleanup_item | jq '.version'
}

function proxy_promote () {
    local environment="$1"
    local version="$2"
    echo "Promoting proxy version $version of env $environment..." >&2
    threescale_call proxy_promote POST "$(breadcrumb_to_path breadcrumb)/proxy/configs/${environment}/${version}/promote.json" "201" -d to=production
}

