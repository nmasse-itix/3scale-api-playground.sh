function policy_list () {
    echo "Finding all policies..." >&2
    threescale_call policies_list GET "$(breadcrumb_to_path breadcrumb)/proxy/policies.json" "200"
    if [ $? -gt 0 ]; then
        return $?
    fi

    get_result policies_list | cleanup_item
}

function policy_update () {
    local policy_chain="$1"

    echo "Updating policies..." >&2
    threescale_call policy_update PUT "$(breadcrumb_to_path breadcrumb)/proxy/policies.json" "200" --data-urlencode "policies_config=$1"
}

function contains_policy () {
    policy_name="$1"
    jq --arg policy_name "$policy_name" -e '[ .[] | select(.name == $policy_name) ] | length != 0' > /dev/null
}

function remove_policy () {
    policy_name="$1"
    jq --arg policy_name "$policy_name" -r '[ .[] | select(.name != $policy_name) ]'
}
