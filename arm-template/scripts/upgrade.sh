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

# Get script current directory
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Variables
PARAMETERS_FILE="${SCRIPT_DIR}/parameters.json"
DEFAULT_RELEASE_VERSION="main"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
FLAG_SUBSCRIPTION=""
FLAG_RESOURCE_GROUP=""
FLAG_NAME=""
FLAG_RELEASE="${DEFAULT_RELEASE_VERSION}"
FLAG_WF_VERSION=""
FLAG_WF_RELEASE_CHANNEL=""
MANAGED_RESOURCE_GROUP=""
PARAMETERS_CONFIGSTORE=""

# Help instructions for this script.
print_usage() {
  printf "\nUSAGE: $0 [flags]

Flags:
  -s  The Subscription ID where the Resource Group for the Managed Application exists (default: none)
  -g  The Resource Group where the Managed Application lives (default: none)
  -n  The name of the Managed Application (default: none)
  -b  The branch name or tag of the Wayfinder Azure release to deploy (default: '${DEFAULT_RELEASE_VERSION}')
  -v  The version of Wayfinder to upgrade to, e.g. 'v1.6.1' (default: none)
  -r  The release channel for the Wayfinder version, e.g. 'releases' (default: none)
  -h  show this help\n"
}

# Check that all required arguments have been supplied.
check_required_arguments() {
    echo "--> Checking if required flags have been provided."
    for var in "FLAG_SUBSCRIPTION" "FLAG_RESOURCE_GROUP" "FLAG_NAME" "FLAG_RELEASE" "FLAG_WF_VERSION" "FLAG_WF_RELEASE_CHANNEL"; do
        if [ -z "${!var}" ]; then
            echo "Error: Variable ${var} has no value."
            print_usage
            exit 1
        fi
    done
}

# Fetch parameters from the Wayfinder Application Config Store
fetch_parameters_configstore() {
    echo "--> Retrieving parameters from the Wayfinder Configuration Store."
    rm -f ${PARAMETERS_FILE}
    local configstore_name=$(az appconfig list --subscription ${FLAG_SUBSCRIPTION} -g ${MANAGED_RESOURCE_GROUP} --query "[0].name" -o tsv)
    az appconfig kv export --subscription ${FLAG_SUBSCRIPTION} -n ${configstore_name} -d file --path ${PARAMETERS_FILE} --format json --yes
    PARAMETERS_CONFIGSTORE=$(jq -r 'del(.wfPlanId, .wfDimension, .wfDimensionInclusiveAmount) | to_entries | .[] | {(.key) : {value: .value}}' ${PARAMETERS_FILE} | jq -cs add)
    PARAMETERS_CONFIGSTORE=$(jq -c ".version.value = \"$FLAG_WF_VERSION\" | .releases.value = \"$FLAG_WF_RELEASE_CHANNEL\"" <<< "$PARAMETERS_CONFIGSTORE")
}

# Fetch the name of the Managed Resource Group where the Wayfinder resources reside.
fetch_mrg_name() {
    echo "--> Retrieving the Managed Resource Group associated with the Managed Application '${FLAG_NAME}'."
    MANAGED_RESOURCE_GROUP=$(az managedapp show --subscription ${FLAG_SUBSCRIPTION} -g ${FLAG_RESOURCE_GROUP} -n ${FLAG_NAME} -o tsv --query managedResourceGroupId | sed 's/.*\///')
}

# Perform an upgrade of the Managed Application by redeploying the ARM Template at a specified version.
upgrade() {
    local deployment_name="wf-upgrade-${TIMESTAMP}-${FLAG_RELEASE}"
    echo "--> Performing an upgrade of Wayfinder, deployment name is '${deployment_name}'."
    az deployment group create --name ${deployment_name} --subscription ${FLAG_SUBSCRIPTION} --resource-group ${MANAGED_RESOURCE_GROUP} --template-uri https://raw.githubusercontent.com/appvia/wayfinder-azure/${FLAG_RELEASE}/arm-template/azuredeploy.json --parameters ${PARAMETERS_CONFIGSTORE}
}

# The main function
main() {
    check_required_arguments
    fetch_mrg_name
    fetch_parameters_configstore
    upgrade
}

# Parse arguments provided to the script and error if any are unexpected
while getopts 's:g:n:b:v:r:h' flag; do
    case "${flag}" in
        s) FLAG_SUBSCRIPTION="${OPTARG}" ;;
        g) FLAG_RESOURCE_GROUP="${OPTARG}" ;;
        n) FLAG_NAME="${OPTARG}" ;;
        b) FLAG_RELEASE="${OPTARG}" ;;
        v) FLAG_WF_VERSION="${OPTARG}" ;;
        r) FLAG_WF_RELEASE_CHANNEL="${OPTARG}" ;;
        h) print_usage && exit 0 ;;
        *) print_usage
        exit 1 ;;
    esac
done

# Run the main function
main
