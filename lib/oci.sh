#!/bin/bash

# Function to get the latest version tag of a Docker image from Docker Hub, Artifactory, or Harbor
get_latest_docker_image_version() {
    local repo_type="$1"
    local repo_id="$2"
    local image_name="$3"
    local artifactory_base_url="$4"
    local R_USER="$5"
    local R_PASS="$6"
    
    if [[ -z "${repo_type}" || -z "${image_name}" ]]; then
        echo "Usage: get_latest_docker_image_version <repo_id> <repo_type> <image_name> [<artifactory_url>|<harbor_url>]"
        return 1
    fi

    case "${repo_type}" in
        docker_hub)
            # Docker Hub API to get tags
            tags_list=$(curl -s "https://registry.hub.docker.com/v2/repositories/${image_name}/tags/?page_size=100")
            if [ "$(echo "$tags_list" | jq '.message')" != "null" ]; then
                echo "Error: Failed to fetch tags for image ${image_name}."
                return 1
            fi
            tags=$(echo "$tags_list" | jq -r '.results[].name')
            ;;
        artifactory)
            if [[ -z "${artifactory_base_url}" ]]; then
                echo "Error: Artifactory base URL is required for Artifactory repository."
                return 1
            fi
             
            # Artifactory API to get tags
            tags_list=$(curl -s -u "$R_USER:$R_PASS" "${artifactory_base_url}/api/docker/${repo_id}/v2/${image_name}/tags/list")
            if [ "$(echo "$tags_list" | jq '.errors')" != "null" ]; then
                echo "Error: Failed to fetch tags for image ${image_name}."
                return 1
            fi
            tags=$(echo "$tags_list" | jq -r '.tags | .[]')
            ;;
        harbor)
            # Harbor API to get tags
            tags_list=$(curl -s -X 'GET' \
                "${artifactory_base_url}/api/v2.0/projects/${repo_id}/repositories/$(printf %s "$image_name" | jq -sRr @uri)/artifacts" \
                -H 'accept: application/json' \
                -H 'X-Accept-Vulnerabilities: application/vnd.security.vulnerability.report; version=1.1, application/vnd.scanner.adapter.vuln.report.harbor+json; version=1.0' \
                -u "$R_USER:$R_PASS" | jq '.[]')
            if [ -z "$tags_list" ]; then
                echo "Error: Failed to fetch tags for image ${image_name}."
                return 1
            fi
            tags=$(echo "$tags_list" | jq -r '.tags[].name')
            ;;
        *)
            echo "Error: Invalid repository type. Valid types are docker_hub, artifactory, harbor."
            return 1
    esac

    if [[ -z "${tags}" ]]; then
        echo "Error: No tags found or unable to fetch tags for image ${image_name}."
        return 1
    fi

    # Find the latest version tag (assuming semantic versioning)
    latest_version=$(echo "${tags}" | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1)

    if [[ -z "${latest_version}" ]]; then
        echo "Error: No version tags found for image ${image_name}."
        return 1
    fi

    echo "${latest_version}"
    return 0
}

increment_version() {
  local version="$1"
  local flag="$2"

  IFS='.' read -r -a parts <<< "$version"

  case $flag in
    major)
      ((parts[0]++))
      parts[1]=0
      parts[2]=0
      ;;
    minor)
      ((parts[1]++))
      parts[2]=0
      ;;
    bug)
      ((parts[2]++))
      ;;
    *)
      echo "Invalid flag. Use 'major', 'minor', or 'bug'."
      return 1
      ;;
  esac

  echo "${parts[0]}.${parts[1]}.${parts[2]}"
}