#!/bin/bash

# #######################################################################################################
# OTHER FUNCTIONS
# #######################################################################################################

# Takes a HELM (OCI) repository URL for a given image as input, and extracts the registry base URL from it.
# Ex: extract_oci_registry_host "registry.axion.local:5001/foo/bar" -> registry.axion.local:5001
function extract_oci_registry_host {
    local repo_url="$1"
    registry_url=${repo_url%%/*}
    echo "$registry_url"
}

# Takes a HELM (HTTP) repository URL for a given image as input, and extracts the registry base URL from it.
# Ex: extract_http_registry_host "http://registry.axion.local:5001/foo/bar" -> registry.axion.local:5001
function extract_http_registry_host {
    local url="$1"
    url_without_subpath=$(echo "$url" | cut -d'/' -f1-3)
    clean_string="${url_without_subpath#http://}"
    clean_string="${clean_string#https://}"
    echo $clean_string
}

# Takes a HELM (OCI) repository URL for a given image as input, and extracts the registry base URL from it, 
# minus the port name if provided in the URL.
# Ex: extract_oci_registry_host "registry.axion.local:5001/foo/bar" -> registry.axion.local
function extract_oci_registry_host_noport {
    local repo_url="$1"
    if [[ $repo_url == *:* ]]; then
        registry_url="${repo_url%:*}"
    else
        registry_url="$repo_url"
    fi
    echo "$registry_url"
}

# Flatten any string into a DNS compatible string
function flatten_url {
    local REQUESTED_HELM_REPO="$1"

    if [[ $REQUESTED_HELM_REPO == https://* ]] || [[ $REQUESTED_HELM_REPO == http://* ]]; then
        STR=$(extract_http_registry_host "$REQUESTED_HELM_REPO")
    else
        STR=$REQUESTED_HELM_REPO
    fi
    CLEANED_STRING=$(echo "$STR" | sed 's/[^a-zA-Z0-9]/-/g')
    FLAT=$(echo "$CLEANED_STRING" | tr -s '-')
    echo "$FLAT"
}

# Generate a secret name based on a repository URL
function secret_repo_name {
    FLAT=$(flatten_url "$1")
    echo "$FLAT-regcreds"
}

# URLEncode a string
function urlencode() {
    local input="$1"
    local output=""

    for (( i=0; i<${#input}; i++ )); do
        local c="${input:$i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) output+="$c" ;;
            *) output+=$(printf '%%%02X' "'$c")
        esac
    done
    echo "$output"
}