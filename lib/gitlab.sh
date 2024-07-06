#!/bin/bash

# #######################################################################################################
# GITLAB FUNCTIONS
# #######################################################################################################

# Get a list of files from a given Gitlab repository folder
function get_gitlab_files_from_folder() {
    local repositoryId="$1"
    local folderPath="$2"
    local branch="$3"
    local personalAccessToken="$4"
    
    local endpoint="https://gitlab.ea.com/api/v4/projects/$(echo -n "$repositoryId" | jq -s -R -r @uri)/repository/tree?path=$(echo -n "$folderPath" | jq -s -R -r @uri)&ref=$branch"
    
    local response=$(curl -s --header "PRIVATE-TOKEN: $personalAccessToken" "$endpoint")

    if [[ $? -ne 0 ]]; then
        echo "Failed to fetch folder content" >&2
        return 1
    fi

    echo "$response" | jq -r '.[] | select(.type == "blob") | .path'
}

# Download a file from a given Gitlab repository
function download_gitlab_file() {
    local repositoryId="$1"
    local branch="$2"
    local filePath="$3"
    local personalAccessToken="$4"
    local outputPath="$5"
    
    local endpoint="https://gitlab.ea.com/api/v4/projects/$(echo -n "$repositoryId" | jq -s -R -r @uri)/repository/files/$(echo -n "$filePath" | jq -s -R -r @uri)/raw?ref=$branch"
    
    curl -s --header "PRIVATE-TOKEN: $personalAccessToken" "$endpoint" -o "$outputPath/$filePath"
    
    if [[ $? -ne 0 ]]; then
        echo "Failed to download file: $filePath" >&2
        return 1
    fi
}

# Returns the Gitlab repo web url based on a Project ID
function get_gitlab_project_web_url() {
    project_search_response=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_GROUP_TOKEN" "$GITLAB_API_URL/projects/$1")
    PROJECT_WEBURL=$(echo $project_search_response | jq -r '.web_url')
    echo "$PROJECT_WEBURL"
}

# Returns the file content from a given Gitlab repo
function get_gitlab_repo_file_content() {
    local GITLAB_PROJECT_ID=$1
    local FILE_PATH=$2
    local BRANCH_NAME=$3
    local GITLAB_GROUP_TOKEN=$4

    FILE_CONTENT=$(curl --header "PRIVATE-TOKEN: $GITLAB_GROUP_TOKEN" "https://gitlab.ea.com/api/v4/projects/$GITLAB_PROJECT_ID/repository/files/$(echo $FILE_PATH | sed 's/\//%2F/g')/raw?ref=$BRANCH_NAME")
    echo $FILE_CONTENT
}

# Add a new Gitlab CI/CD variable to a given project
function add_gitlab_cicd_masked_variable() {
    local GITLAB_PROJECT="$1"
    local GITLAB_TOKEN="$2"
    local VARIABLE_KEY="$3"
    local VARIABLE_VALUE="$4"

    HAS_VAR=$(curl --silent --request GET --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
        --header "Content-Type: application/json" \
        "https://gitlab.ea.com/api/v4/projects/$GITLAB_PROJECT/variables" | jq -r '.[] | .key' | grep "$VARIABLE_KEY")

    if [ "$HAS_VAR" != "" ]; then
        echo " => Variable \"$VARIABLE_KEY\" already exists, deleting first..."
        curl --silent --request DELETE --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "https://gitlab.ea.com/api/v4/projects/$GITLAB_PROJECT/variables/$VARIABLE_KEY" 
    fi

    echo " => Creating Gitlab CI Variable \"$VARIABLE_KEY\"..."
    json_payload=$(jq -n \
        --arg key "$VARIABLE_KEY" \
        --arg value "$VARIABLE_VALUE" \
        '{
            "key": $key,
            "value": $value,
            "variable_type": "file",
            "protected": false,
            "masked": true,
            "raw": true
        }')

    curl --silent --request POST --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
        --header "Content-Type: application/json" \
        --data "$json_payload" \
        "https://gitlab.ea.com/api/v4/projects/$GITLAB_PROJECT/variables"
}

# Add a project ID as an authorized project to trigger pipelines on a given repository
function gitlab_cicd_project_add_project_token_access() {
    local GITLAB_TOKEN="$1"
    local GITLAB_PROJECT="$2"
    local PROJECT_TO_ALLOW="$3"

    local API_URL="https://gitlab.ea.com/api/v4/projects/$GITLAB_PROJECT"

    HEADERS="PRIVATE-TOKEN: $GITLAB_TOKEN"

    HAS_DATA_PROJECT=$(curl -s --header "$HEADERS" "$API_URL/job_token_scope/allowlist" | jq '.[] | .id' | grep "$PROJECT_TO_ALLOW")
    if [ "$HAS_DATA_PROJECT" == "" ]; then
        echo " => Allowing project access to the job token..."
        curl --header "$HEADERS" --request POST \
        --url "$API_URL/job_token_scope/allowlist" \
        --header 'Content-Type: application/json' \
        --data '{ "target_project_id": '"$PROJECT_TO_ALLOW"' }'
    fi
}

# Get a Gitlab project ID by repository URL
function get_gitlab_project_id_by_repo_url() {
  local repo_url=$1
  local gitlab_token=$2

  repo_url=$(echo "$repo_url" | sed 's/\.git$//')
  local namespace_project=$(echo "$repo_url" | sed -E 's~https://gitlab.[^/]+/~~')
  local api_url="https://gitlab.ea.com/api/v4/projects/$(urlencode "$namespace_project")"
  local response=$(curl --silent --header "PRIVATE-TOKEN: $gitlab_token" "$api_url")
  local project_id=$(echo "$response" | jq -r '.id')
  
  echo "$project_id"
}
