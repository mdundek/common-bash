#!/bin/bash

# #######################################################################################################
# KUBERNETES FUNCTIONS
# #######################################################################################################

# Check if a specific resource exists
function check_resource_type_exists() {
  local resource_type="$1"

  # Check if the resource type exists using kubectl api-resources
  if kubectl api-resources | grep -qw "^${resource_type}"; then
    echo "true"
  else
    echo "false"
  fi
}

# Delete all resources of a type in all namespaces
function delete_all_k8s_ns_resources_by_type() {
    local resource_type="$1"
    
    # Get all namespaces
    namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')

    for namespace in $namespaces; do
        # Get all resource names of the specified type in the current namespace
        resource_names=$(kubectl get "$resource_type" -n "$namespace" -o jsonpath='{.items[*].metadata.name}')
        for resource_name in $resource_names; do
            # We make sure that ArgoCD is not uninstalling itself
            if [ "$resource_type" == "Application" ] || [ "$resource_type" == "application" ]; then
                if [ "$resource_name" != "argo-cd" ]; then
                    # Delete each resource
                    echo " => kubectl delete $resource_type $resource_name -n $namespace"
                    kubectl delete "$resource_type" "$resource_name" -n "$namespace"
                fi
            else
                # Delete each resource
                echo " => kubectl delete $resource_type $resource_name -n $namespace"
                kubectl delete "$resource_type" "$resource_name" -n "$namespace"
            fi
        done
    done
}

# Delete all resources of a type that are cluster scoped resources
function delete_all_axion_owned_k8s_ns_resources_by_type() {
    local resource_type="$1"
    
    # Get all namespaces
    namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')

    for namespace in $namespaces; do
        # Get all resource names of the specified type in the current namespace
        resource_names=$(kubectl get "$resource_type" -n "$namespace" -o jsonpath='{.items[*].metadata.name}')
        for resource_name in $resource_names; do
            # Check if the resource has the specified annotation
            annotation_value=$(kubectl get "$resource_type" "$resource_name" -n "$namespace" -o jsonpath="{.metadata.annotations['axion\.neotek\.ea\.com/from-installation']}")
            if [ "$annotation_value" == "true" ]; then
                # We make sure that ArgoCD is not uninstalling itself
                if [ "$resource_type" == "Application" ] || [ "$resource_type" == "application" ]; then
                    if [ "$resource_name" != "argo-cd" ]; then
                        # Delete each resource
                        echo " => kubectl delete $resource_type $resource_name -n $namespace"
                        kubectl delete "$resource_type" "$resource_name" -n "$namespace"
                    fi
                else
                    # Delete each resource
                    echo " => kubectl delete $resource_type $resource_name -n $namespace"
                    kubectl delete "$resource_type" "$resource_name" -n "$namespace"
                fi
            fi
        done
    done
}

# Delete all resources of a type that are cluster scoped resources
function delete_all_k8s_cluster_resources_by_type() {
    local resource_type="$1"

    # Get all resource names of the specified type in the current namespace
    resource_names=$(kubectl get "$resource_type" -o jsonpath='{.items[*].metadata.name}')
    
    for resource_name in $resource_names; do
        # Delete each resource
        echo " => kubectl delete $resource_type $resource_name"
        kubectl delete "$resource_type" "$resource_name"
    done
}

# Delete all resources of a type that are cluster scoped resources
function delete_all_axion_owned_k8s_cluster_resources_by_type() {
    local resource_type="$1"

    # Get all resource names of the specified type in the current namespace
    resource_names=$(kubectl get "$resource_type" -o jsonpath='{.items[*].metadata.name}')
    
    for resource_name in $resource_names; do
        annotation_value=$(kubectl get "$resource_type" "$resource_name" -o jsonpath="{.metadata.annotations['axion\.neotek\.ea\.com/from-installation']}")
        if [ "$annotation_value" == "true" ]; then
            # Delete each resource
            echo " => kubectl delete $resource_type $resource_name"
            kubectl delete "$resource_type" "$resource_name"
        fi
    done
}

# Delete all resources of a type in all namespaces
function delete_all_unhealthy_k8s_ns_resources_by_type() {
    local resource_type="$1"
    local T_SELECTOR_NAME="$2"
    local T_SELECTOR_VALUE="$3"
    local T_STATUS_VALUE="$4"

    # Get all namespaces
    namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')

    for namespace in $namespaces; do
        # Get all resource names of the specified type in the current namespace
        resource_names=$(kubectl get "$resource_type" -n "$namespace" -o jsonpath='{.items[*].metadata.name}')
        for resource_name in $resource_names; do
            # Check if the resource is unhealthy
            RESOURCE_HEALTHY=$(is_resource_healthy "$namespace" "$resource_name" "$resource_type" "$T_SELECTOR_NAME" "$T_SELECTOR_VALUE" "$T_STATUS_VALUE")
            if [ "$RESOURCE_HEALTHY" == "false" ]; then
                # Delete each resource
                echo " => kubectl delete $resource_type $resource_name -n $namespace"
                kubectl delete "$resource_type" "$resource_name" -n "$namespace"
            fi
        done
    done
}

# Delete all resources of a type that are cluster scoped resources
function delete_all_unhealthy_k8s_cluster_resources_by_type() {
    local resource_type="$1"
    local T_SELECTOR_NAME="$2"
    local T_SELECTOR_VALUE="$3"
    local T_STATUS_VALUE="$4"

    # Get all resource names of the specified type
    resource_names=$(kubectl get "$resource_type" -o jsonpath='{.items[*].metadata.name}')
    
    for resource_name in $resource_names; do
        RESOURCE_HEALTHY=$(is_resource_healthy "" "$resource_name" "$resource_type" "$T_SELECTOR_NAME" "$T_SELECTOR_VALUE" "$T_STATUS_VALUE")
        if [ "$RESOURCE_HEALTHY" == "false" ]; then
            # Delete each resource
            echo " => kubectl delete $resource_type $resource_name"
            kubectl delete "$resource_type" "$resource_name"
        fi
    done
}

# Wait for a resource to be ready
function wait_for_resource_status {
    T_NAMESPACE="$1"
    T_NAME="$2"
    T_KIND="$3"
    T_TIMEOUT="$4"
    T_SELECTOR_NAME="$5"
    T_SELECTOR_VALUE="$6"
    T_STATUS_VALUE="$7"
    KEEP_RUNNING_ON_ERROR="$8"
    
    if [ ! -z "$T_NAMESPACE" ]; then
        T_NAMESPACE=" -n $T_NAMESPACE"
    else
        T_NAMESPACE=""
    fi
    end=$((SECONDS+$T_TIMEOUT))
    success="false"
    while [ $SECONDS -lt $end ]; do
        if [ "$(kubectl get ${T_KIND} ${T_NAME}${T_NAMESPACE} -o json | jq '.status')" != "null" ]; then
            RESOURCE_STATUS=$(kubectl get ${T_KIND} ${T_NAME}${T_NAMESPACE} -o json | jq '.status')
            RESOURCE_CONDITIONS=$(echo $RESOURCE_STATUS | jq '.conditions')
            if [ "$RESOURCE_CONDITIONS" != "null" ]; then
                CONDITION_TARGET=$(echo $RESOURCE_CONDITIONS | jq -r '.[] | select(.'$T_SELECTOR_NAME'=="'$T_SELECTOR_VALUE'")')
                if [ "$CONDITION_TARGET" != "null" ]; then
                    INSTALLED_CONDITION_STATUS=$(echo $CONDITION_TARGET | jq -r '.status')
                    if [ "$INSTALLED_CONDITION_STATUS" == "$T_STATUS_VALUE" ]; then
                        success="true"
                        break
                    fi
                fi
            fi
        fi
        echo " => Resource $T_NAME not ready yet, waiting..."
        sleep 5
    done
    if [ "$success" == "false" ]; then
        echo " => Resource $T_NAME not ready in $T_TIMEOUT seconds"
        if [ "$KEEP_RUNNING_ON_ERROR" == "true" ]; then
            return 1
        else
            exit 1
        fi
    fi
    echo " => Resource $T_NAME is ready!"
}

# Check if specific resource is healthy
# Call signature: is_resource_healthy <NAMESPACE> <RESOURCE_NAME> <RESOURCE_KIND> <SELECTOR_NAME> <SELECTOR_VALUE> <STATUS_VALUE>
function is_resource_healthy {
    T_NAMESPACE="$1"
    T_NAME="$2"
    T_KIND="$3"
    T_SELECTOR_NAME="$5"
    T_SELECTOR_VALUE="$6"
    T_STATUS_VALUE="$7"
    
    if [ ! -z "$T_NAMESPACE" ]; then
        T_NAMESPACE=" -n $T_NAMESPACE"
    else
        T_NAMESPACE=""
    fi
    isHealthy="false"
    if [ "$(kubectl get ${T_KIND} ${T_NAME}${T_NAMESPACE} -o json | jq '.status')" != "null" ]; then
        RESOURCE_STATUS=$(kubectl get ${T_KIND} ${T_NAME}${T_NAMESPACE} -o json | jq '.status')
        RESOURCE_CONDITIONS=$(echo $RESOURCE_STATUS | jq '.conditions')
        if [ "$RESOURCE_CONDITIONS" != "null" ]; then
            CONDITION_TARGET=$(echo $RESOURCE_CONDITIONS | jq -r '.[] | select(.'$T_SELECTOR_NAME'=="'$T_SELECTOR_VALUE'")')
            if [ "$CONDITION_TARGET" != "null" ]; then
                INSTALLED_CONDITION_STATUS=$(echo $CONDITION_TARGET | jq -r '.status')
                if [ "$INSTALLED_CONDITION_STATUS" == "$T_STATUS_VALUE" ]; then
                    isHealthy="true"
                fi
            fi
        fi
    fi
    echo "$isHealthy"
}

# Check if specific namespace exists
function namespace_exists {
    # The name of the chart to check
    local TARGET_NS=$1

    # Get the list of all installed helm charts with their details
    RESOURCE_LIST=$(kubectl get ns)

    # Check if the provided chart name exists in the list
    if echo "$RESOURCE_LIST" | awk '{print $1}' | grep -q "^${TARGET_NS}$"; then
        echo "true"
    else
        echo "false"
    fi
}

# Check if specific resource CR exists
function namespace_resource_exists {
    # The name of the chart to check
    local RESOURCE_NS=$1
    local RESOURCE_TYPE=$2
    local RESOURCE_NAME=$3

    local TARGET_K8S_HOST=$4
    local TARGET_K8S_TOKEN=$5

    # Get the list of all resources of the specified type in the current namespace
    if [ "$TARGET_K8S_HOST" != "" ]; then
        RESOURCE_LIST=$(kubectl get $RESOURCE_TYPE -n $RESOURCE_NS --server=$TARGET_K8S_HOST --token=$TARGET_K8S_TOKEN --insecure-skip-tls-verify=true 2>/dev/null)
    else
        RESOURCE_LIST=$(kubectl get $RESOURCE_TYPE -n $RESOURCE_NS 2>/dev/null)
    fi

    # Check if the provided resource name exists in the list
    if echo "$RESOURCE_LIST" | awk '{print $1}' | grep -q "^${RESOURCE_NAME}$"; then
        echo "true"
    else
        echo "false"
    fi
}

# Checks if a specific cluster scoped resource exists
function cluster_resource_exists {
    # The name of the chart to check
    local RESOURCE_TYPE=$1
    local RESOURCE_NAME=$2

    local TARGET_K8S_HOST=$3
    local TARGET_K8S_TOKEN=$4

    # Get the list of all installed helm charts with their details
    if [ "$TARGET_K8S_HOST" != "" ]; then
        RESOURCE_LIST=$(kubectl get $RESOURCE_TYPE --server=$TARGET_K8S_HOST --token=$TARGET_K8S_TOKEN --insecure-skip-tls-verify=true 2>/dev/null)
    else
        RESOURCE_LIST=$(kubectl get $RESOURCE_TYPE 2>/dev/null)
    fi  

    # Check if the provided chart name exists in the list
    if echo "$RESOURCE_LIST" | awk '{print $1}' | grep -q "^${RESOURCE_NAME}$"; then
        echo "true"
    else
        echo "false"
    fi
}

# Create OCI secrets
function create_oci_secret {
    local SECRET_NAMESPACE=$1
    local SECRET_NAME=$2
    local _OCI_SERVER=$3
    local _OCI_USERNAME=$4
    local _OCI_PASSWORD=$5

    TARGET_SECRET_EXISTS=$(namespace_resource_exists "$SECRET_NAMESPACE" "Secret" "$SECRET_NAME")
    if [ $TARGET_SECRET_EXISTS == "true" ]; then
        echo " => Secret "$SECRET_NAME" does exist, deleting it first"
        kubectl -n $SECRET_NAMESPACE delete Secret $SECRET_NAME 
    fi
    echo " => Creating secret $SECRET_NAME in namespace $SECRET_NAMESPACE"
    kubectl -n $SECRET_NAMESPACE create secret docker-registry $SECRET_NAME \
        --docker-server=$OCI_SERVER \
        --docker-username=$_OCI_USERNAME \
        --docker-password=$_OCI_PASSWORD
}

# Get the credentials for a private repository
function get_private_repo_creds {
    local __repo=$1
    local __username=$2
    local __password=$3

    SECRET_NAME=$(secret_repo_name "$4")
    SECRET_NAMESPACE="$5"
    if [ "$SECRET_NAMESPACE" == "" ]; then
        SECRET_NAMESPACE="axion-system"
    fi
    
    REG_CREDS_JSON=$(kubectl get secret ${SECRET_NAME} -n $SECRET_NAMESPACE -o yaml)
    DOCKER_CONFIG_JSON=$(echo "$REG_CREDS_JSON" | yq e '.data[".dockerconfigjson"]' - | base64 -d)

    # Extract values using jq
    registry=$(echo "$DOCKER_CONFIG_JSON" | jq -r '.auths | keys[0]')
    username=$(echo "$DOCKER_CONFIG_JSON" | jq -r ".auths[\"$registry\"].username")
    password=$(echo "$DOCKER_CONFIG_JSON" | jq -r ".auths[\"$registry\"].password")

    eval $__repo="$registry"
    eval $__username="$username"
    eval $__password="$password"
}

# Apply a k8s resource with a given number of leading spaces
function kubectl_apply() {
    local input_str="$1"
    local num_spaces="$2"
    local IFS=$'\n'  # Internal Field Separator set to newline to handle multi-line strings
    local lines=($input_str)  # Split the input by newlines into an array
    local result=""

    for line in "${lines[@]}"; do
        # Calculate leading spaces to remove
        trimmed_line="${line}"
        for (( i=0; i<num_spaces; i++ )); do
            if [[ "${trimmed_line}" == " "* ]]; then
                trimmed_line="${trimmed_line:1}"
            fi
        done
        result+="$trimmed_line"$'\n'
    done

    # Remove the trailing newline
    result=${result%$'\n'}
    kubectl apply -f - <<EOF
$result
EOF
}

# Get a specific value from a secret
function get_secret_field_value() {
    TEMP_SECRET_NAME=$1
    TEMP_SECRET_NAMESPACE=$2
    SECRET_FIELD=$3

    SECRET_JSON=$(kubectl get secret $TEMP_SECRET_NAME -n $TEMP_SECRET_NAMESPACE -o yaml)
    SECRET_FIELD_VALUE=$(echo "$SECRET_JSON" | yq e ".data.$SECRET_FIELD" - | base64 -d)
    echo $SECRET_FIELD_VALUE
}

# Wait until all resources in a namespace are healthy
function wait_until_all_k8s_resources_healthy {
    local namespace="$1"
    local timeout="$2"
    local end_time=$((SECONDS + timeout))

    while [[ $SECONDS -lt $end_time ]]; do
        all_healthy=true

        # Check Deployments
        deployments=$(kubectl get deployments -n "$namespace" --no-headers -o custom-columns=":metadata.name")
        for deployment in $deployments; do
            replicas=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.spec.replicas}')
            availableReplicas=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.status.availableReplicas}')
            
            if [[ "$replicas" != "$availableReplicas" ]]; then
                all_healthy=false
                echo "Deployment $deployment is not healthy"
            fi
        done

        # Check StatefulSets
        statefulsets=$(kubectl get statefulsets -n "$namespace" --no-headers -o custom-columns=":metadata.name")
        for statefulset in $statefulsets; do
            replicas=$(kubectl get statefulset "$statefulset" -n "$namespace" -o jsonpath='{.spec.replicas}')
            readyReplicas=$(kubectl get statefulset "$statefulset" -n "$namespace" -o jsonpath='{.status.readyReplicas}')
            
            if [[ "$replicas" != "$readyReplicas" ]]; then
                all_healthy=false
                echo "StatefulSet $statefulset is not healthy"
            fi
        done

        if [[ "$all_healthy" == true ]]; then
            echo " => All resources in namespace $namespace are healthy"
            return 0
        fi

        echo " => Waiting for resources to become healthy..."
        sleep 5
    done

    echo " => Timeout after $timeout seconds. Some resources are still not healthy."
    exit 1
}