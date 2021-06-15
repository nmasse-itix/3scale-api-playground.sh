function find_first_account () {
    echo "Finding the default first account..." >&2
    threescale_call find_first_account GET "/accounts.json?state=approved&page=1&per_page=1" "200"
    if [ $? -gt 0 ]; then
        return $?
    fi

    get_result find_first_account | cleanup_list | jq '.[0]'
}
