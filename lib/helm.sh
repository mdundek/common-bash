#!/bin/bash

# #######################################################################################################
# HELM FUNCTIONS
# #######################################################################################################

# Login to a HELM registry
function helm_login {
    local _REQUIRE_AUTH=$1

    if [ "$_REQUIRE_AUTH" == "true" ]; then
        local _AXION_REPO=$2
        local _TARGET_REPO=$3
        local _TARGET_SECRET_NAMESPACE=$4

        evaluate_helm_registry \
            IS_OCI \
            IS_PRIVATE \
            TARGET_REPO \
            "$_REQUIRE_AUTH" \
            "$_AXION_REPO" \
            "$_TARGET_REPO"

        get_private_repo_creds REG_REPO REG_USERNAME REG_PASSWORD $TARGET_REPO $_TARGET_SECRET_NAMESPACE

        if [ "$IS_OCI" == "true" ]; then
            OCI_REPO_NAKED=$(extract_oci_registry_host "$_TARGET_REPO")
            echo "$REG_PASSWORD" | helm registry login $OCI_REPO_NAKED --insecure -u $REG_USERNAME --password-stdin
        else
            echo "$REG_PASSWORD" | helm registry login $_TARGET_REPO --insecure -u $REG_USERNAME --password-stdin
        fi
    fi
}

# Check if a specific resource exists
function evaluate_chart_deployment_topology() {
    local NAME=$1
    local NAMESPACE=$2

    # Is there a Application object for this?
    local __is_app=$3
    # Is there a HELM Chart for this?
    local __is_helm=$4
    # IS it installed?
    local __is_installed=$5

    echo " => Collecting deployment information for $NAME in $NAMESPACE"

    if [ "$(namespace_exists "$NAMESPACE")" == "false" ]; then
        eval $__is_app="false"
        eval $__is_helm="false"
        eval $__is_installed="false"
    else
        if [ "$(check_resource_type_exists "applications")" == "true" ]; then
            if [ "$(namespace_resource_exists argocd "Application" "$NAME")" == "true" ]; then
                eval $__is_app="true"
                eval $__is_installed="true"
            else
                eval $__is_app="false"
            fi
        else
            eval $__is_app="false"
        fi
        if [ "$(is_chart_healthy "$NAMESPACE" "$NAME")" != "na" ]; then
            eval $__is_helm="true"
            eval $__is_installed="true"
        else
            eval $__is_helm="false"
        fi
    fi
    if [ "$__is_app" == "false" ] && [ "$__is_helm" == "false" ]; then
        eval $__is_installed="false"
    fi
}

# Check if HELM Chart is installed & healthy
# Returns:
# "true" if chart is installed, deployed and healthy
# "false" if chart is installed but not deployed
# "na" if chart is not installed
function is_chart_healthy {
    # The name of the chart to check
    local CHART_NS=$1
    local CHART_NAME=$2

    # Get the list of all installed helm charts with their details
    CHARTS_LIST=$(helm list -n $CHART_NS)

    # Check if the provided chart name exists in the list
    if echo "$CHARTS_LIST" | awk '{print $1}' | grep -q "^$CHART_NAME$"; then
        # Chart exists, now check if the status is 'deployed'
        CHARTS_DEPLOYED_LIST=$(helm list -n $CHART_NS --deployed)
        if echo "$CHARTS_DEPLOYED_LIST" | awk '{print $1}' | grep -q "^$CHART_NAME$"; then
            echo "true"
        else
            echo "false"
        fi
    else
        echo "na"
    fi
}

# Evaluate if a target HELM registry is a OCI or HTTP based registry, if it is a public or a private registry,
# and what the target repo base URL is based on a few input parameters, including what the Axion base registry URL is.
#
# NOTE: This is a convenience function that aims at externalizing a lot of the String analytical code logic in 
# combination with certain contextual input parameters, with the aim of keeping the calling code more streamlined
# and easy to read.
#
# The function call signature is: 
# evaluate_helm_registry \
#     <SET VAR:is_oci> \
#     <SET VAR:is_private> \
#     <SET VAR:target_repo> \
#     <AXION_REPO_AUTH> \
#     <AXION_REPO> \
#     <REQUESTED_HELM_REPO>
#
# Please note that we are using the bash "eval" mechanism here in order to manage multiple return values for a single 
# function call. The principle is based on the fact that the caller provides one or more variable names that will be set
# from within the function when called. Those can then be evaluated by the caller. 
#
# Let's take an example like the following one:
# evaluate_helm_registry \
#            IS_OCI \             <- Will be set to true or false based on the repo type
#            IS_PRIVATE \         <- Will be set to true if the provided $TARGET_REPO matches the internal $AXION_REPO, false otherwise, 
#            TARGET_REPO \        <- Will be set to the target repository base URL, extracted from the $TARGET_REPO according to it's type (OCI vs HTTP)
#            "$REQUIRE_AUTH" \    <- INPUT VALUE: Specify if the target repo requires authentication or not
#            "$AXION_REPO" \      <- INPUT VALUE: Specify if the default Axion HELM repo URL, used for target repo comparisons
#            "$TARGET_REPO"       <- INPUT VALUE: Specify the full HELM target repo URL
function evaluate_helm_registry {
    local __is_oci=$1
    local __is_private=$2
    local __target_repo=$3

    local AXION_REPO_AUTH=$4
    local AXION_REPO=$5
    local REQUESTED_HELM_REPO=$6

    local TARGET_IS_OCI=""
    local AXION_IS_OCI=""
    local AXION_REPO_HTTP=""
    local TARGET_REPO_HTTP=""
    local AXION_REPO_OCI=""
    local TARGET_REPO_OCI=""

    if [[ $REQUESTED_HELM_REPO == https://* ]] || [[ $REQUESTED_HELM_REPO == http://* ]]; then
        TARGET_IS_OCI="0"
        TARGET_REPO_HTTP=$(extract_http_registry_host $REQUESTED_HELM_REPO)
    else
        TARGET_IS_OCI="1"
        TARGET_REPO_OCI=$REQUESTED_HELM_REPO
    fi
    if [ "$AXION_REPO" != "" ]; then
        if [[ $AXION_REPO == https://* ]] || [[ $AXION_REPO == http://* ]]; then
            AXION_IS_OCI="0"
            AXION_REPO_HTTP=$(extract_http_registry_host $AXION_REPO)
        else
            AXION_IS_OCI="1"
            AXION_REPO_OCI=$AXION_REPO
        fi
    else
        AXION_IS_OCI=""
    fi

    function _oci_no_auth {
        eval $__is_oci="true"
        eval $__is_private="$1"
        eval $__target_repo="$2"
    }

    function _oci_auth {
        eval $__is_oci="true"
        eval $__is_private="$1"
        eval $__target_repo="$2"
    }

    function _http_no_auth {
        eval $__is_oci="false"
        eval $__is_private="$1"
        eval $__target_repo="$2"
    }

    function _http_auth {
        eval $__is_oci="false"
        eval $__is_private="$1"
        eval $__target_repo="$2"
    }

    if [ "$AXION_IS_OCI" != "" ] && [ "$AXION_IS_OCI" == "1" ] && [ "$TARGET_IS_OCI" == "1" ]; then
        if [ "$TARGET_REPO_OCI" == "$AXION_REPO_OCI" ]; then
            # PRIVATE REGISTRY
            # OCI REPO
            if [ "$AXION_REPO_AUTH" == "true" ]; then
                # REQUIRES AUTH
                _oci_auth "true" "$REQUESTED_HELM_REPO"
            else
                # NO AUTH
                _oci_no_auth "true" "$REQUESTED_HELM_REPO"
            fi
        else
            # PUBLIC REGISTRY
            # OCI REPO
            if [ "$AXION_REPO_AUTH" == "true" ]; then
                # REQUIRES AUTH
                _oci_auth "false" "$REQUESTED_HELM_REPO"
            else
                # NO AUTH
                _oci_no_auth "false" "$REQUESTED_HELM_REPO"
            fi
        fi
    elif [ "$AXION_IS_OCI" != "" ] && [ "$AXION_IS_OCI" == "0" ] && [ "$TARGET_IS_OCI" == "0" ]; then
        if [ "$TARGET_REPO_HTTP" == "$AXION_REPO_HTTP" ]; then
            # PRIVATE REGISTRY
            # HTTP REPO
            if [ "$AXION_REPO_AUTH" == "true" ]; then
                # REQUIRES AUTH
                _http_auth "true" "$(extract_http_registry_host $REQUESTED_HELM_REPO)"
            else
                # NO AUTH
                _http_no_auth "true" "$(extract_http_registry_host $REQUESTED_HELM_REPO)"
            fi
        else
            # PUBLIC REGISTRY
            # HTTP REPO
            if [ "$AXION_REPO_AUTH" == "true" ]; then
                # REQUIRES AUTH
                _http_auth "false" "$(extract_http_registry_host $REQUESTED_HELM_REPO)"
            else
                # NO AUTH
                _http_no_auth "false" "$(extract_http_registry_host $REQUESTED_HELM_REPO)"
            fi
        fi
    else
        if [ "$TARGET_IS_OCI" == "1" ]; then
            # PUBLIC REGISTRY
            # OCI REPO
            if [ "$AXION_REPO_AUTH" == "true" ]; then
                # REQUIRES AUTH
                _oci_auth "false" "$REQUESTED_HELM_REPO"
            else
                # NO AUTH
                _oci_no_auth "false" "$REQUESTED_HELM_REPO"
            fi
        else
            # PUBLIC REGISTRY
            # HTTP REPO
            if [ "$AXION_REPO_AUTH" == "true" ]; then
                # REQUIRES AUTH
                _http_auth "false" "$(extract_http_registry_host $REQUESTED_HELM_REPO)"
            else
                # NO AUTH
                _http_no_auth "false" "$(extract_http_registry_host $REQUESTED_HELM_REPO)"
            fi
        fi
    fi
}