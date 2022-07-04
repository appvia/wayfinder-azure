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

# Default variables
PARAMETERS_FILE="${SCRIPT_DIR}/parameters.json"
DEFAULT_RELEASE_VERSION="main"
FLAG_SUBSCRIPTION=""
FLAG_RESOURCE_GROUP=""
FLAG_NAME="${DEFAULT_APP_NAME}"
FLAG_RELEASE="${DEFAULT_RELEASE_VERSION}"

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
    for var in "FLAG_SUBSCRIPTION" "FLAG_RESOURCE_GROUP" "FLAG_NAME" "FLAG_RELEASE"; do
        if [ -z "${!var}" ]; then
            echo "Error: Variable ${var} has no value."
            print_usage
            exit 1
        fi
    done
}

# Fetch parameters originally provided to the Managed Application at time of installation.
# TODO: For future-proofing, we should implement a parameter store and fetch parameters from that.
#       The Managed Application parameters are fixed at time of installation, so the parameter store
#       can be used to keep track of any new additions and supply it to the ARM template
fetch_parameters() {
    parameters=$(az managedapp show --subscription ${FLAG_SUBSCRIPTION} -g ${FLAG_RESOURCE_GROUP} -n ${FLAG_NAME} --query parameters)

    # Remove the type key and generate a json file with the parameters
    echo $parameters | jq 'walk(if type == "object" then with_entries(select(.key | test("type") | not)) else . end)' > ${PARAMETERS_FILE}
}

# Fetch the name of the Managed Resource Group where the Wayfinder resources reside.
fetch_mrg_name() {
    az managedapp show --subscription ${FLAG_SUBSCRIPTION} -g ${FLAG_RESOURCE_GROUP} -n ${FLAG_NAME} -o tsv --query managedResourceGroupId | sed 's/.*\///'
}

# Perform an upgrade of the Managed Application by redeploying the ARM Template at a specified version.
upgrade() {
    timestamp=$(date +%Y%m%d-%H%M%S)
    az deployment group create --name wf-upgrade-${timestamp}-${FLAG_RELEASE} --resource-group ${1} --template-uri https://raw.githubusercontent.com/appvia/wayfinder-azure/${FLAG_RELEASE}/arm-template/azuredeploy.json --parameters @${PARAMETERS_FILE}
}

# The main function
main() {
    check_required_arguments
    fetch_parameters
    mrg=$(fetch_mrg_name)
    upgrade $mrg
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
