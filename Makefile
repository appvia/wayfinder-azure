.DEFAULT_GOAL := dist
BUILD_DIR=.build
TEMPLATE_DIR=arm-template
WF_VERSION ?= v1.6.1
WF_RELEASE_CHANNEL ?= releases
WF_PLAN_ID ?= standard
WF_DIMENSION_INCLUSIVE_AMOUNT ?= 8
TRACKING_ID ?= pid-3b0884cf-abb0-46cf-a48b-55ee7245e8a9-partnercenter
TENANT_ID ?= 7a770e35-b455-4df2-a276-b07408438d9a

clean:
	@echo "--> Removing existing build assets"
	rm -rf ${BUILD_DIR}/

create-build-dir: clean
	@echo "--> Creating build directory"
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

dist: create-build-dir copy-to-build-dir strip-license
	@echo "--> Creating a package for external tenants"
	jq \
		'.variables.wfPlanId = "${WF_PLAN_ID}" | \
		.variables.wfDimensionInclusiveAmount = "${WF_DIMENSION_INCLUSIVE_AMOUNT}" | \
		.parameters.version.defaultValue = "${WF_VERSION}" | \
		.parameters.releases.defaultValue = "${WF_RELEASE_CHANNEL}" | \
		.resources[0].name = "${TRACKING_ID}" | \
		.parameters.tenantId.defaultValue = "${TENANT_ID}"' \
		${BUILD_DIR}/azuredeploy.json > ${BUILD_DIR}/mainTemplate.json

	@$(MAKE) package

package:
	@echo "--> Packaging contents"
	cd ${BUILD_DIR} && zip app.zip mainTemplate.json createUiDefinition.json viewDefinition.json scripts/wayfinder.sh
	@echo "--> Package file is located at: ${BUILD_DIR}/app.zip"
