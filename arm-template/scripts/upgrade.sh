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
FLAG_NAME="${DEFAULT_APP_NAME}"
FLAG_RELEASE="${DEFAULT_RELEASE_VERSION}"
MANAGED_RESOURCE_GROUP=""
PARAMETERS_MANAGEDAPP=""
PARAMETERS_CONFIGSTORE=""

# Help instructions for this script.
print_usage() {
  printf "\nUSAGE: $0 [flags]

Flags:
  -s  The Subscription ID where the Resource Group for the Managed Application exists (default: none)
  -g  The Resource Group where the Managed Application lives (default: none)
  -n  The name of the Managed Application (default: none)
  -r  The branch name or tag of the Wayfinder Azure release to deploy (default: '${DEFAULT_RELEASE_VERSION}')
  -h  show this help\n"
}

# Check that all required arguments have been supplied.
check_required_arguments() {
    echo "--> Checking if required flags have been provided."
    for var in "FLAG_SUBSCRIPTION" "FLAG_RESOURCE_GROUP" "FLAG_NAME" "FLAG_RELEASE"; do
        if [ -z "${!var}" ]; then
            echo "Error: Variable ${var} has no value."
            print_usage
            exit 1
        fi
    done
}

# Fetch parameters originally provided to the Managed Application at time of installation.
fetch_parameters_managedapp() {
    echo "--> Fetching parameters that were provided at install time to the Managed Application '${FLAG_NAME}'."
    PARAMETERS_MANAGEDAPP=$(az managedapp show --subscription ${FLAG_SUBSCRIPTION} -g ${FLAG_RESOURCE_GROUP} -n ${FLAG_NAME} --query parameters)
}

# Fetch parameters within an Application Config Store
fetch_parameters_configstore() {
    echo "--> Retrieving parameters within the Configuration Store '${MANAGED_RESOURCE_GROUP}'."
    local parameters=$(az appconfig kv list --subscription ${FLAG_SUBSCRIPTION} -n ${MANAGED_RESOURCE_GROUP})
    PARAMETERS_CONFIGSTORE=$(echo ${parameters} | jq '.[] | {(.key) : {value: .value}}' | jq -cs add)
}

# Fetch the name of the Managed Resource Group where the Wayfinder resources reside.
fetch_mrg_name() {
    echo "--> Retrieving the Managed Resource Group associated with the Managed Application '${FLAG_NAME}'."
    MANAGED_RESOURCE_GROUP=$(az managedapp show --subscription ${FLAG_SUBSCRIPTION} -g ${FLAG_RESOURCE_GROUP} -n ${FLAG_NAME} -o tsv --query managedResourceGroupId | sed 's/.*\///')
}

# Create an Application Config Store containing Parameters for the Wayfinder ARM Template
create_configstore() {
    if ! az appconfig show --subscription ${FLAG_SUBSCRIPTION} -g ${MANAGED_RESOURCE_GROUP} -n ${MANAGED_RESOURCE_GROUP} &>/dev/null; then
        echo "--> Configuration Store for Managed Application '${FLAG_NAME}' does not exist, creating one now."

        fetch_parameters_managedapp
        local keys=$(echo ${PARAMETERS_MANAGEDAPP} | jq -c 'keys')
        local values=$(echo ${PARAMETERS_MANAGEDAPP} | jq -c '[.[].value]')

        az deployment group create --name wf-configStore-${TIMESTAMP}-${FLAG_RELEASE} --resource-group ${MANAGED_RESOURCE_GROUP} --template-uri https://raw.githubusercontent.com/appvia/wayfinder-azure/${FLAG_RELEASE}/arm-template/configStore.json --parameters configStoreName=${MANAGED_RESOURCE_GROUP} keyValueNames=${keys} keyValueValues=${values}
    else
        echo "--> Configuration Store '${MANAGED_RESOURCE_GROUP}' already exists, skipping creation."
    fi
}

# Perform an upgrade of the Managed Application by redeploying the ARM Template at a specified version.
upgrade() {
    local deployment_name="wf-upgrade-${TIMESTAMP}-${FLAG_RELEASE}"
    echo "--> Performing an upgrade of Wayfinder, deployment name is '${deployment_name}'."
    az deployment group create --name ${deployment_name} --resource-group ${MANAGED_RESOURCE_GROUP} --template-uri https://raw.githubusercontent.com/appvia/wayfinder-azure/${FLAG_RELEASE}/arm-template/azuredeploy.json --parameters ${PARAMETERS_CONFIGSTORE}
}

# The main function
main() {
    check_required_arguments
    fetch_mrg_name
    create_configstore
    fetch_parameters_configstore
    upgrade
}

# Parse arguments provided to the script and error if any are unexpected
while getopts 's:g:n:r:h' flag; do
    case "${flag}" in
        s) FLAG_SUBSCRIPTION="${OPTARG}" ;;
        g) FLAG_RESOURCE_GROUP="${OPTARG}" ;;
        n) FLAG_NAME="${OPTARG}" ;;
        r) FLAG_RELEASE="${OPTARG}" ;;
        h) print_usage && exit 0 ;;
        *) print_usage
        exit 1 ;;
    esac
done

# Run the main function
main
