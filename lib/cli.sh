#!/bin/bash

########################################
#
########################################
log() {
    printf -- "$1";
}

log_success() {
    printf -- "\033[32m$1\033[0m";
}

log_error() {
    printf -- "\033[31m$1\033[0m";
}

log_dim() {
    printf -- "\033[1;34m$1\033[0m";
}

########################################
# yes_no "Do you wish to continue" CONTINUE_INSTALL
# if [ "$CONTINUE_INSTALL" == "n" ]; then
#     exit 0
# fi
########################################
yes_no() {
    local  __resultvar=$2
    read_input "$1 (y/n)?" _R
    while [ "$_R" != 'y' ] && [ "$_R" != 'n' ]; do
        read_input "Invalide answer, try again (y/n):" _R
    done
    eval $__resultvar="'$_R'"
}

########################################
# VALID_FS=("One" "Two" "Three")
# combo_index MOUNT_INDEX "What filesystem is used for your volume provisionning" "Your choice #:" "${VALID_FS[@]}"
# echo "$MOUNT_INDEX"
########################################
combo_index() {
    local  __resultvar=$1
    shift
    local title="$1"
    shift 
    local question="$1"
    shift 
    log "$title\n\n"
    local arr=("$@")
    local arrLength="${#arr[@]}"
    local RESP
    _I=1
    for VAL in "${arr[@]}"; do :
        log_dim "  $_I) $VAL\n"
        _I=$(($_I+1))
    done
    log "\n"
    read_input "$question" RESP
    while [[ "$RESP" -gt "$arrLength" ]] || [[ "$RESP" -lt "1" ]]; do
        read_input "Invalide answer, try again:" RESP
    done
    eval $__resultvar="'$(($RESP-1))'"
}

########################################
# 
########################################
combo_value() {
    local  __resultvar=$1
    shift
    local title="$1"
    shift 
    local question="$1"
    shift 
    log "$title\n\n"
    local arr=("$@")
    local arrLength="${#arr[@]}"
    local RESP
    _I=1
    for VAL in "${arr[@]}"; do :
        log_dim "  $_I) $VAL\n"
        _I=$(($_I+1))
    done
    log "\n"
    read_input "$question" RESP
    while [[ "$RESP" -gt "$arrLength" ]] || [[ "$RESP" -lt "1" ]]; do
        read_input "Invalide answer, try again:" RESP
    done
    local _FR="${arr[$(($RESP-1))]}"
    eval $__resultvar="'$_FR'"
}

########################################
# 
########################################
read_input() {
    local  __resultvar=$2
    local _VAL
    log_success "$1 "
    read _VAL
    while [[ "$_VAL" == '' ]]; do
        log_error "Required field, try again: "
        read _VAL
    done
    if [[ "$__resultvar" ]]; then
        eval $__resultvar="'$_VAL'"
    else
        echo "$_VAL"
    fi
}