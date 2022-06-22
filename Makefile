BUILD_DIR=.build
TEMPLATE_DIR=arm-template

clean-build-dir:
	@echo "--> Cleaning build directory (if it exists)"
	rm -rf ${BUILD_DIR}/

create-build-dir:
	@echo "--> Creating build directory"
	mkdir ${BUILD_DIR}

copy-to-build-dir:
	@echo "--> Copying assets to build directory"
	cp -R ${TEMPLATE_DIR}/* ${BUILD_DIR}/

package-tenant-appvia: clean-build-dir create-build-dir copy-to-build-dir
	@echo "--> Creating a package for internal testing within an Appvia Tenant"
	jq 'walk(if type == "object" then with_entries(select(.key | test("delegatedManagedIdentityResourceId") | not)) else . end)' ${TEMPLATE_DIR}/azuredeploy.json > ${BUILD_DIR}/azuredeploy.json
	zip ${BUILD_DIR}/app.zip ${BUILD_DIR}/mainTemplate.json ${BUILD_DIR}/createUiDefinition.json ${BUILD_DIR}/scripts/wayfinder.sh
	@echo "--> Package file is located at: ${BUILD_DIR}/app.zip"

package-tenant-external: clean-build-dir create-build-dir copy-to-build-dir
	@echo "--> Creating a package for external tenants"
	zip ${BUILD_DIR}/app.zip ${BUILD_DIR}/mainTemplate.json ${BUILD_DIR}/createUiDefinition.json ${BUILD_DIR}/scripts/wayfinder.sh
	@echo "--> Package file is located at: ${BUILD_DIR}/app.zip"
