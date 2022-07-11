#!/usr/bin/env bash
#
# Copyright 2021 Appvia Ltd <info@appvia.io>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
set -o errexit
set -o pipefail
${TRACE:+set -x}

RETRY_DELAY_SECONDS=10
MAX_RETRIES=360
AZ_SCRIPTS_OUTPUT_PATH=${AZ_SCRIPTS_OUTPUT_PATH:-"./scriptoutputs.json"}

# Test for and retrieve the Kubelet Identity
get_kubelet_identity() {
    echo "--> Checking for Kubelet Identity. Retry Delay: ${RETRY_DELAY_SECONDS} seconds, Max Retries: ${MAX_RETRIES}"
    RETRY_COUNT=0
    while [ $RETRY_COUNT -le $MAX_RETRIES ]; do
        RETRY_COUNT=$((RETRY_COUNT+1))
        echo "--> Iteration Count: ${RETRY_COUNT}"
        sleep ${RETRY_DELAY_SECONDS}

        KUBELET_MI_RESOURCE_ID=$(az aks show --name wayfinder -g ${RESOURCE_GROUP} -o tsv --query identityProfile.kubeletidentity.resourceId 2> /dev/null)
        if [ -z "$KUBELET_MI_RESOURCE_ID" ]; then
            continue
        else
            KUBELET_MI_PRINCIPAL_ID=$(az identity show --ids "${KUBELET_MI_RESOURCE_ID}" -o tsv --query principalId 2> /dev/null)
            if [ -z "$KUBELET_MI_PRINCIPAL_ID" ]; then
                continue
            else
                echo "--> Kubelet Identity was successfully detected. Resource ID: '${KUBELET_MI_RESOURCE_ID}', Principal ID: '${KUBELET_MI_PRINCIPAL_ID}'"
                generate_script_output ${KUBELET_MI_RESOURCE_ID} ${KUBELET_MI_PRINCIPAL_ID}
                return 0
            fi
        fi
    done
    return 1
}

# Generate an output file to expose values from the deployment script
generate_script_output() {
    JSON_STRING=$(jq -n \
        --arg krid "${1}" \
        --arg kpid "${2}" \
        '{kubeletResourceId: $krid, kubeletPrincipalId: $kpid}'
    )
    echo ${JSON_STRING} > ${AZ_SCRIPTS_OUTPUT_PATH}
}

if ! get_kubelet_identity; then
    echo "--> ERROR: Kubelet Identity could not be found"
    exit 1
fi
