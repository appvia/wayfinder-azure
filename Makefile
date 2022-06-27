BUILD_DIR=.build
TEMPLATE_DIR=arm-template
WF_VERSION ?= latest
WF_RELEASE_CHANNEL ?= releases
TRACKING_ID ?= pid-d67dc5ed-2255-482d-8bdb-5c81425b3d83-partnercenter

create-build-dir:
	@echo "--> Creating build directory"
	rm -rf ${BUILD_DIR}/
	mkdir ${BUILD_DIR}

copy-to-build-dir:
	@echo "--> Copying assets to build directory"
	cp -R ${TEMPLATE_DIR}/ ${BUILD_DIR}/
	rm -f ${BUILD_DIR}/mainTemplate.json ${BUILD_DIR}/*.zip

strip-license:
	@echo "--> Stripping License step from UI definition"
	jq \
		'del(.parameters.steps[] | select(.name == "license")) | \
		del(.parameters.outputs.email) | \
		del(.parameters.outputs.license)' \
		${TEMPLATE_DIR}/createUiDefinition.json > ${BUILD_DIR}/createUiDefinition.json
	jq \
		'del(.parameters.email) | \
		del(.parameters.license) | \
		del(.. | .environmentVariables? // empty | .[] | select(.name == "WF_EMAIL")) | \
		del(.. | .environmentVariables? // empty | .[] | select(.name == "WF_LICENSE"))' \
		${TEMPLATE_DIR}/azuredeploy.json > ${BUILD_DIR}/azuredeploy.json

create-appvia-package: create-build-dir copy-to-build-dir strip-license
	@echo "--> Creating a package for internal testing within an Appvia Tenant"
	jq \
		'walk(if type == "object" then with_entries(select(.key | test("delegatedManagedIdentityResourceId") | not)) else . end) | \
		.parameters.version.defaultValue = "${WF_VERSION}" | \
		.parameters.releases.defaultValue = "${WF_RELEASE_CHANNEL}" | \
		.resources[0].name = "${TRACKING_ID}"' \
		${BUILD_DIR}/azuredeploy.json > ${BUILD_DIR}/mainTemplate.json

	$(MAKE) package

create-external-package: create-build-dir copy-to-build-dir strip-license
	@echo "--> Creating a package for external tenants"
	jq \
		'.parameters.version.defaultValue = "${WF_VERSION}" | \
		.parameters.releases.defaultValue = "${WF_RELEASE_CHANNEL}" | \
		.resources[0].name = "${TRACKING_ID}"' \
		${BUILD_DIR}/azuredeploy.json > ${BUILD_DIR}/mainTemplate.json

	$(MAKE) package

package:
	cd ${BUILD_DIR} && zip app.zip mainTemplate.json createUiDefinition.json scripts/wayfinder.sh
