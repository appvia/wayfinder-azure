BUILD_DIR=".build"
TEMPLATE_DIR="arm-template"
WF_VERSION ?= latest
WF_RELEASE_CHANNEL ?= releases
TRACKING_ID ?= pid-d67dc5ed-2255-482d-8bdb-5c81425b3d83-partnercenter

create-build-dir:
	@echo "--> Creating build directory"
	rm -rf ${BUILD_DIR}/
	mkdir ${BUILD_DIR}

copy-to-build-dir:
	@echo "--> Copying assets to build directory"
	cp -R ${TEMPLATE_DIR}/* ${BUILD_DIR}/

create-appvia-package: create-build-dir copy-to-build-dir
	@echo "--> Creating a package for internal testing within an Appvia Tenant"
	jq \
		'walk(if type == "object" then with_entries(select(.key | test("delegatedManagedIdentityResourceId") | not)) else . end) | \
		.parameters.version.defaultValue = "${WF_VERSION}" | \
		.parameters.releases.defaultValue = "${WF_RELEASE_CHANNEL}" | \
		.resources[0].name = "${TRACKING_ID}"' \
		${TEMPLATE_DIR}/azuredeploy.json > ${BUILD_DIR}/azuredeploy.json

	zip ${BUILD_DIR}/app.zip ${BUILD_DIR}/mainTemplate.json ${BUILD_DIR}/createUiDefinition.json ${BUILD_DIR}/scripts/wayfinder.sh
	@echo "--> Package file is located at: ${BUILD_DIR}/app.zip"

create-external-package: create-build-dir copy-to-build-dir
	@echo "--> Creating a package for external tenants"
	jq \
		'.parameters.version.defaultValue = "${WF_VERSION}" | \
		.parameters.releases.defaultValue = "${WF_RELEASE_CHANNEL}" | \
		.resources[0].name = "${TRACKING_ID}"' \
		${TEMPLATE_DIR}/azuredeploy.json > ${BUILD_DIR}/azuredeploy.json

	zip ${BUILD_DIR}/app.zip ${BUILD_DIR}/mainTemplate.json ${BUILD_DIR}/createUiDefinition.json ${BUILD_DIR}/scripts/wayfinder.sh
	@echo "--> Package file is located at: ${BUILD_DIR}/app.zip"
