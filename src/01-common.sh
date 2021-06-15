declare tmp=$(mktemp -d -t threescale-XXXXXXXXXX)

function threescale_call () {
    request_name="$1"
    method="$2"
    service="$3"
    expected_http_codes="$4"
    shift 4

    # Make HTTP methods uppercase
    method="${method^^}"

    local -a curl_args=( -sk --write-out "%{http_code}" -o "$tmp/$request_name.json" -X "$method" "$@")
    local url="https://$ADMIN_PORTAL_HOSTNAME/admin/api$service"

    if [[ "$method" == "GET" || "$method" == "DELETE" ]]; then
        if [[ "$url" =~ .*\?.* ]]; then
            url="$url&access_token=$THREESCALE_TOKEN"
        else
            url="$url?access_token=$THREESCALE_TOKEN"
        fi
    else
        curl_args+=( "-d" "access_token=$THREESCALE_TOKEN" )
    fi

    curl_args+=( "$url" )

    if [ "${CURL_DEBUG:-}" != "" ]; then
        echo curl "${curl_args[@]}" ">" "$tmp/$request_name.code" >&2
    fi

    curl "${curl_args[@]}" > "$tmp/$request_name.code"
    ret=$?
    if [ $ret -gt 0 ]; then
        echo "curl exited with rc = $ret" >&2
        return $ret
    fi

    if [ "${CURL_DEBUG:-}" != "" ]; then
        echo "=> HTTP $(cat "$tmp/$request_name.code")" >&2
    fi
    
    if ! egrep -q "^$expected_http_codes\$" "$tmp/$request_name.code"; then
        echo "Unexpected HTTP code: $(cat "$tmp/$request_name.code")" >&2
        return 1
    fi

    return 0
}

function get_result_file () {
    request_name="$1"
    echo -n "$tmp/$request_name.json"
}

function get_result () {
    request_name="$1"
    cat "$tmp/$request_name.json"
}

function cleanup_list () {
    jq 'to_entries | .[0].value | map(to_entries | .[0].value)'
}

function cleanup_item () {
    jq 'to_entries | .[0].value'
}

function map_to_curl () {
    local -n map=$1
    for k in "${!map[@]}"; do
        v="$(urlencode "${map[$k]}")"
        echo -d "$k=$v"
    done
}

declare -a breadcrumb

function breadcrumb_to_path () {
    join_by "/" "" ${breadcrumb[@]}
}

declare last_object_id

function apply () {
    local object_type="$1"
    local state="$2"
    local -n object=$3

    ${object_type}_list > "$tmp/apply_list.json"
    ret=$?
    if [ $ret -gt 0 ]; then
        echo "${object_type}_list exited with rc = $ret" >&2
        return $ret
    fi
    local list="$(cat $tmp/apply_list.json)"

    external_id="$(external_id_factory $object_type)"

    last_object_id=
    case "$state" in
    "present")
        if echo "$list" | "$(contains_external_id_factory "$object_type")" "$external_id" "${object[$external_id]}"; then
            local id="$(echo "$list" | "$(id_of_external_id_factory "$object_type")" "$external_id" "${object[$external_id]}")"
            "${object_type}_update" "$id" object
            ret=$?
            if [ $ret -gt 0 ]; then
                echo "${object_type}_update exited with rc = $ret" >&2
                return $ret
            fi
            last_object_id="$id"
        else
            "${object_type}_create" object
            ret=$?
            if [ $ret -gt 0 ]; then
                echo "${object_type}_create exited with rc = $ret" >&2
                return $ret
            fi
            last_object_id="$(get_result "${object_type}_create" | cleanup_item | jq -r .id)"
        fi
        ;;
    "absent")
        if echo "$list" | "$(contains_external_id_factory "$object_type")" "$external_id" "${object[$external_id]}"; then
            local id="$(echo "$list" | "$(id_of_external_id_factory "$object_type")" "$external_id" "${object[$external_id]}" )"
            "${object_type}_delete" "$id"
            ret=$?
            if [ $ret -gt 0 ]; then
                echo "${object_type}_delete exited with rc = $ret" >&2
                return $ret
            fi
        fi
        ;;
    esac
}

function delete_all () {
    local object_type="$1"
    "${object_type}_list" | jq -r '.[] | .id' | while read id; do
        "${object_type}_delete" "$id"
    done
}

function external_id_factory () {
    local object_type="$1"
    id="${threescale_external_id[$object_type]:-}"
    echo "${id:-system_name}"
}

function contains_external_id_factory () {
    local object_type="$1"
    fn="${threescale_contains_external_id[$object_type]:-}"
    echo "${fn:-contains_external_id}"
}

function id_of_external_id_factory () {
    local object_type="$1"
    fn="${threescale_id_of_external_id[$object_type]:-}"
    echo "${fn:-id_of_external_id}"
}

function contains_external_id_with_prefix () {
    jq --arg k "$1" --arg v "$2" -e '[ .[] | select(.[$k] | startswith($v + ".")) ] | length != 0' > /dev/null
}

function id_of_external_id_with_prefix () {
    jq --arg k "$1" --arg v "$2" -r '.[] | select(.[$k] | startswith($v + ".")) | .id '
}

function contains_external_id () {
    jq --arg k "$1" --arg v "$2" -e '[ .[] | select(.[$k] == $v) ] | length != 0' > /dev/null
}

function id_of_external_id () {
    jq --arg k "$1" --arg v "$2" -r '.[] | select(.[$k] == $v) | .id '
}

function contains_numerical_external_id () {
    jq --arg k "$1" --arg v "$2" -e '[ .[] | select(.[$k] == ($v|tonumber)) ] | length != 0' > /dev/null
}

function id_of_numerical_external_id () {
    jq --arg k "$1" --arg v "$2" -r '.[] | select(.[$k] == ($v|tonumber)) | .id '
}
