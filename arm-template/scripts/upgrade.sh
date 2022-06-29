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
PARAMETERS_FILE="wf-parameters.env"

error_exit() {
    echo "Error: ${1}"
    exit 1
}

# Check that Managed Resource Group ID was provided
check_arg() {
    if [ -z "$1" ]
    then
        error_exit "No argument supplied. A Managed Resource Group ID must be provided, e.g. : $(basename $0) mrg-wayfinder-20220101150000"
    fi
}

fetch_parameters() {
    # Create an empty env file with parameters for the installer
    echo "" > ${PARAMETERS_FILE}

    # Fetch environment variables that were passed to the deployment script
    variables=$(az deployment-scripts show --name wayfinder-installer --resource-group $1 --query environmentVariables)

    # Create a parameters file
    echo $variables | jq -c '.[]' | while read i; do
        key=$(echo $i | jq -r '.name')
        value=$(echo $i | jq -r '.value')
        echo "export $key=$value" >> ${PARAMETERS_FILE}
    done
}

upgrade() {
    source ${PARAMETERS_FILE} && bash ${SCRIPT_DIR}/wayfinder.sh
}

main() {
    check_arg ${1}
    fetch_parameters ${1}
    upgrade
}

main ${1}
