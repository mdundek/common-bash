#!/bin/bash

# Function to get the latest version tag of a Docker image from Docker Hub, Artifactory, or Harbor
get_latest_docker_image_version() {
    local repo_type="$1"
    local repo_id="$2"
    local image_name="$3"
    local artifactory_base_url="$4"
    local harbor_base_url="$5"
    
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
            tags_list=$(curl -s "${artifactory_base_url}/api/docker/${repo_id}/v2/${image_name}/tags/list")
            if [ "$(echo "$tags_list" | jq '.errors')" != "null" ]; then
                echo "Error: Failed to fetch tags for image ${image_name}."
                return 1
            fi
            tags=$(echo "$tags_list" | jq -r '.tags | .[]')
            ;;
        harbor)
            if [[ -z "${harbor_base_url}" ]]; then
                echo "Error: Harbor base URL is required for Harbor repository."
                return 1
            fi
            # Harbor API to get tags
            tags=$(curl -s -u "username:password" "${harbor_base_url}/api/v2.0/projects/library/repositories/${image_name}/artifacts" | jq -r '.[].tags[].name')
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