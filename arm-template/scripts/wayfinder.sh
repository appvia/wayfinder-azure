#!/bin/bash
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
set -o nounset
set -o pipefail
${TRACE:+set -x}

WF_INSTALL_URL=${WF_INSTALL_URL:-https://storage.googleapis.com/wayfinder-releases/latest/wf-cli-linux-amd64}

error_exit() {
    echo ${1}
    exit 1
}

check_var() {
  local var_name=${1?'expected varname'}
  if [[ -z ${!var_name:-} ]]; then
    error_exit "Missing environment variable: '${var_name}'"
  fi
}

download() {
  curl -sSL ${WF_INSTALL_URL} --output /tmp/wf
  chmod +x /tmp/wf
  mv /tmp/wf /usr/local/bin/wf
}

deploy() {
  wf install --use-existing-cluster \
    --cloud azure \
    --cluster-name ${CLUSTER_NAME} \
    --account ${SUBSCRIPTION_ID} \
    --region ${REGION} \
    --instance-identifier ${WF_INSTANCE_ID} \
    --non-interactive \
    --disable-idp \
    --azure-resourcegroup ${RESOURCE_GROUP} \
    --azure-node-resourcegroup ${NG_RESOURCE_GROUP} \
    --azure-default-identity ${WF_IDENTITY_NAME} \
    --azure-ingress-ip-name ${IP_NAME} \
    --json-file ${AZ_SCRIPTS_OUTPUT_PATH} \
    ${LICENSE_OPT:-}
}

check-envs() {
  for var in \
    WF_INSTALL_URL \
    SUBSCRIPTION_ID \
    REGION \
    CLUSTER_NAME \
    RESOURCE_GROUP \
    NG_RESOURCE_GROUP \
    WF_IDENTITY_NAME \
    IP_NAME \
    WF_INSTANCE_ID \
    AZ_SCRIPTS_OUTPUT_PATH \
    ; do check_var ${var:-}
  done

  if [[ -n ${WF_LICENSE_KEY:-} ]]; then
    LICENSE_OPT="--license-key ${WF_LICENSE_KEY}"
  elif [[ -n ${WF_LICENSE_EMAIL:-} ]]; then
    LICENSE_OPT="--license-email ${WF_LICENSE_EMAIL}"
  fi
}

usage() {
  cat <<EOF

Usage: $(basename $0)
  --check-only
  -h|--help                 : display this usage menu
EOF
  if [[ -n $@ ]]; then
    echo "[error] $@"
    exit 1
  fi
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-only)
      CHECK_ONLY=true
      shift 1
      ;;
    -h | --help) usage ;;
    *) shift 1 ;;
  esac
done

check-envs

if [[ ${CHECK_ONLY:-} == 'true' ]]; then
  echo "CHECKS OK"
  # TODO: fail early option, run WF with verify license key after WF-997
else
  download
  deploy
fi
