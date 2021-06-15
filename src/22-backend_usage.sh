function backend_usage_list () {
    echo "Finding all backend_usage..." >&2
    threescale_call backend_usage_list GET "$(breadcrumb_to_path breadcrumb)/backend_usages.json" "200"
    if [ $? -gt 0 ]; then
        return $?
    fi

    get_result backend_usage_list | jq 'map(to_entries |.[0].value)'
}

function backend_usage_create () {
    local -n backend_usage=$1
    
    local -A api_call_payload
    for key in "${!backend_usage[@]}"; do
        if [ "$key" == "backend_id" ]; then
            api_call_payload[backend_api_id]="${backend_usage[backend_id]}"
        else
            api_call_payload[$key]="${backend_usage[$key]}"
        fi
    done

    echo "Creating backend_usage with backend_id = ${api_call_payload[backend_api_id]:-}..." >&2
    threescale_call backend_usage_create POST "$(breadcrumb_to_path breadcrumb)/backend_usages.json" "201" $(map_to_curl api_call_payload)
}
