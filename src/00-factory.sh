declare -A threescale_object_types=( ["backend"]="backend_apis" ["service"]="services" ["metric"]="metrics" ["method"]="methods" ["mapping_rule"]="mapping_rules" ["backend_usage"]="backend_usages" ["application_plan"]="application_plans" ["application_apikey"]="applications" ["application_appid"]="applications" )
declare -A threescale_contains_external_id=( ["metric"]="contains_external_id_with_prefix" ["method"]="contains_external_id_with_prefix" ["backend_usage"]="contains_numerical_external_id")
declare -A threescale_id_of_external_id=( ["metric"]="id_of_external_id_with_prefix" ["method"]="id_of_external_id_with_prefix" ["backend_usage"]="id_of_numerical_external_id")
declare -A threescale_external_id=( ["backend_usage"]="backend_id" ["application_apikey"]="user_key" ["application_appid"]="application_id" )

template=$(cat <<"EOF"
function OBJECT_TYPE_list () {
    echo "Finding all OBJECT_TYPE..." >&2
    threescale_call OBJECT_TYPE_list GET "$(breadcrumb_to_path breadcrumb)/URL_PART.json" "200"
    if [ $? -gt 0 ]; then
        return $?
    fi

    get_result OBJECT_TYPE_list | cleanup_list
}

function OBJECT_TYPE_create () {
    local -n OBJECT_TYPE=$1
    local stable_id="$(external_id_factory OBJECT_TYPE)"
    echo "Creating OBJECT_TYPE with $stable_id ${OBJECT_TYPE[$stable_id]:-}..." >&2
    threescale_call OBJECT_TYPE_create POST "$(breadcrumb_to_path breadcrumb)/URL_PART.json" "201" $(map_to_curl OBJECT_TYPE)
}

function OBJECT_TYPE_update () {
    local id=$1
    local -n OBJECT_TYPE=$2
    local stable_id="$(external_id_factory OBJECT_TYPE)"
    echo "Updating OBJECT_TYPE with $stable_id ${OBJECT_TYPE[$stable_id]:-} and id $id..." >&2
    threescale_call OBJECT_TYPE_update PUT "$(breadcrumb_to_path breadcrumb)/URL_PART/$id.json" "200" $(map_to_curl OBJECT_TYPE)
}

function OBJECT_TYPE_delete () {
    local id=$1
    echo "Deleting OBJECT_TYPE with id $id..." >&2
    threescale_call OBJECT_TYPE_delete DELETE "$(breadcrumb_to_path breadcrumb)/URL_PART/$id.json" "200"
}
EOF
)

for object_type in "${!threescale_object_types[@]}"; do
    url_part="${threescale_object_types[$object_type]}"
    eval "$(echo "$template" | sed "s/OBJECT_TYPE/$object_type/g; s/URL_PART/$url_part/g")"
done
