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

# General packaging script for the ARM templates and associated
# Marketplace definition files.

set -o errexit
set -o nounset
set -o pipefail
${TRACE:+set -x}

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
ASSETS_DIR="${PROJECT_DIR}/assets"

# Check we have required deps first (just 'jq' at the moment).
command -v jq >/dev/null || echo "Missing 'jq' - please install it and re-run this script."

# Generate a full all-bells-and-whistles Marketplace UI definition.
generate_full_ui() {
  echo "Generating full Marketplace UI definition..."
  cp "$ASSETS_DIR"/createUiDefinition.json "$PROJECT_DIR"
}

# Generate a Marketplace UI definition without the Licensing step.
generate_no_license_ui() {
  echo "Generating Marketplace UI definition with no Licensing step..."
  jq 'del(.parameters.steps[] | select(.name == "license"))' "$ASSETS_DIR"/createUiDefinition.json >"$PROJECT_DIR"/createUiDefinition.json
}

# Package up the generate UI definition and templates as a zip for
# submission to the Marketplace.
package() {
  echo "TODO: stub for packaging task"
  # Might create a new package/ folder for all assets that get
  # packaged up in this step; if so, then we'll probably
  # move the ARM template and generated UI defs there and
  # just keep the top-level folder clean.
}

# Help text for the script.
help() {
  printf "Usage: %s <task> <args>\n\n" "$0"
  printf "Tasks:\n"
  compgen -A function | cat -n
}

# Exit the script with extreme prejudice.
die() {
  echo >&2 "Error: ${@}"
  exit 1
}

if [ $# -ne 1 ]; then
  die "missing action"
fi

action=$1
case $action in
  generate_full_ui | generate_no_license_ui | package | help)
    "$@"
    ;;
  *)
    die "invalid action '${action}'"
    ;;
esac
