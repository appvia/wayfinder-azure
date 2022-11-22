# Wayfinder - Azure Marketplace Assets

- [Marketplace Links](#marketplace-links)
- [Development](#development)
  - [Required Tools](#required-tools)
  - [Published Assets](#published-assets)
  - [Branch and Tagging Behaviour](#branch-and-tagging-behaviour)
    - [Branch: Main](#branch-main)
    - [Branch: Develop](#branch-develop)
    - [Pull Requests](#pull-requests)
    - [Tags](#tags)
- [Deployment](#deployment)
- [Upgrade](#upgrade)
- [Cleanup](#cleanup)
- [Issuing new versions](#issuing-new-versions)
  - [Create assets](#create-assets)
  - [Update the Marketplace listing](#update-the-marketplace-listing)

---

## Marketplace Links

**Note:** Access must first be granted via [Partner Portal User Management](https://partner.microsoft.com/en-us/dashboard/account/v3/usermanagement#users).

- **Marketplace Offers:** https://partner.microsoft.com/en-us/dashboard/marketplace-offers/overview
- **Production Listing:** https://partner.microsoft.com/en-us/dashboard/commercial-marketplace/offers/3b0884cf-abb0-46cf-a48b-55ee7245e8a9/overview
- **Technical Configuration:** https://partner.microsoft.com/en-us/dashboard/commercial-marketplace/offers/3b0884cf-abb0-46cf-a48b-55ee7245e8a9/plans/79f87324-ae57-4ec9-a648-5d6cca31b781/technicalconfiguration
- **Customer Marketplace Listing:** https://azuremarketplace.microsoft.com/en-gb/marketplace/apps/appvialtd.wayfinder?tab=Overview

---

## Development

### Required Tools

- Azure CLI
- JQ

### Published Assets

One asset is produced and published on the Marketplace:
- An `app.zip` file containing the ARM Template files and the deployment script used to run the Wayfinder installer

### Branch and Tagging Behaviour

#### Branch: Main

The `main` branch is the default branch for the repository, confirmed working with the latest public and issued final version of Wayfinder.

#### Branch: Develop

The `develop` branch points at the latest published development version of Wayfinder, which is not yet ready for release. The Wayfinder binary for these releases is fetched from: https://storage.googleapis.com/wayfinder-dev-releases/latest/wf-cli-linux-amd64

This branch is to be used in Wayfinder end-to-end testing prior to issuing a new tagged release of Wayfinder. If a failure is found in the E2E against this develop branch, a new issue should be created in [JIRA](https://appviakore.atlassian.net/jira/software/projects/WF/boards/11). The likelihood is that the template or WF installer flags need updating to support any new changes introduced in the product.

**Note:** If this repository requires an update, you must run `make dev-latest` and publish the resulting `app.zip` file to the "E2E" Offer.

- **[Offer Listing](https://partner.microsoft.com/en-us/dashboard/commercial-marketplace/offers/d67dc5ed-2255-482d-8bdb-5c81425b3d83/overview)**
- **[Technical Plan](https://partner.microsoft.com/en-us/dashboard/commercial-marketplace/offers/d67dc5ed-2255-482d-8bdb-5c81425b3d83/plans/558d30e3-1587-4130-a827-36b9d5c91dd4/technicalconfiguration)**

#### Pull Requests

A CI pipeline is kicked off when a PR is raised or updated, this will:
- Point at the Wayfinder Version referenced in the `Makefile`
- Build an `app.zip` file that would be used to update and publish the **Live** Azure Marketplace Offer.

#### Tags

The Marketplace Technical Configuration has a strict tagging format, `{integer}.{integer}.{integer}`. Both Wayfinder versions and Azure ARM template versions could move independently, and so this repository will be tagged using the format `v{major}.{minor}.{patch}-arm.{azure-template-version}`, which keeps in line with how we manage AWS Marketplace versions.

When uploading a new package file to the Azure listing, the version should follow Wayfinder (e.g. `1.5.0`), and any subsequent template updates (after the initial published version) will have a incrementing digit suffixed to the version. This is an unlikely and rare case where the template has encountered a failure after a version has already been published (e.g. Azure have made a breaking change conflicting with the ARM template spec).

**Example 1:**
- **Product Version:** v1.6.1
- **Repository Version:** v1.6.1-arm.1 (the first version)
- **Marketplace Listing:** 1.6.11

**Example 2:**
- **Product Version:** v1.6.1
- **Repository Version:** v1.6.1-arm.5 (template has been incremented 4 times since v1.6.1 was first published)
- **Marketplace Listing:** 1.6.15

Tags are produced off the `develop` branch, validated and tested in the Azure Marketplace, and then merged into the `main` branch. Because tags are associated with a product version, the version must be updated in the Makefile prior to tagging (modify the value for `WF_VERSION`).

> **Notes:**<br/>
> The Azure Marketplace Offer will list a tagged version of the ARM template. This must be updated **every time** there a new version of the Product or this Repository template is released.

---

## Deployment

**Offer IDs:**
- Official Published Listing: `wayfinder` (or `wayfinder-preview` for drafted changes)
- E2E Offer for Dev Testing: `wayfindertest-preview`

Run the below command to accept terms for the relevant Offer:
```sh
SUBSCRIPTION_ID="f21fbcee-a453-4e05-9d85-28a8bdb2970f" # Replace with your ID

# Live Offer
az vm image terms accept --publisher appvialtd --offer wayfinder --plan standard --subscription ${SUBSCRIPTION_ID}

# E2E dev-latest Offer
az vm image terms accept --publisher appvialtd --offer wayfindertest-preview --plan standard --subscription ${SUBSCRIPTION_ID}
```

**Deploy Live & Tagged Version:**
```sh
MRG_NAME="mrg-wayfinder-$(date '+%Y%m%d%H%M%S')"

az managedapp create --subscription <subscription-id> -g <rg-for-managed-app> -n wfmanagedappname -l uksouth --kind Marketplace --plan-version <azure-plan-version> --plan-publisher appvialtd --plan-product wayfinder --plan-name standard -m /subscriptions/<subscription-id>/resourceGroups/${MRG_NAME}
```

**Override the Wayfinder installer version:**
```sh
MRG_NAME="mrg-wayfinder-$(date '+%Y%m%d%H%M%S')"

az managedapp create --subscription <subscription-id> -g <rg-for-managed-app> -n wfmanagedappname -l uksouth --kind Marketplace --plan-version <azure-plan-version> --plan-publisher appvialtd --plan-product wayfinder --plan-name standard -m /subscriptions/<subscription-id>/resourceGroups/${MRG_NAME} --parameters '{ "releases": { "value": "releases" }, "version": { "value": "v1.6.1" } }'
```

**Deploy unlisted E2E version:**
```sh
MRG_NAME="mrg-wayfinder-$(date '+%Y%m%d%H%M%S')"

az managedapp create --subscription <subscription-id> -g <rg-for-managed-app> -n wfmanagedappname -l uksouth --kind Marketplace --plan-version 0.0.0 --plan-publisher appvialtd --plan-product wayfindertest-preview --plan-name standard -m /subscriptions/<subscription-id>/resourceGroups/${MRG_NAME}
```

## Upgrade

```sh
BRANCH="some-new-release" # The branch or tag of this repository containing the ARM template files to deploy
WF_CHANNEL="releases" # The release channel to use for fetching the WF binary
WF_VERSION="v1.6.1" # The version of WF to deploy

./arm-template/scripts/upgrade.sh -s <subscription-id> -g <rg-for-managed-app> -n wfmanagedappname -b ${BRANCH} -r ${WF_CHANNEL} -v ${WF_VERSION}
```

## Cleanup

```sh
az managedapp delete --subscription <subscription-id> -g <rg-for-managed-app> -n wfmanagedappname
```

---

## Issuing new versions

### Create assets

- Live Offer: `make dist`
- E2E Offer: `make dev-latest`

The resulting file is located at: `.build/app.zip`

### Update the Marketplace listing

1. Navigate to [Wayfinder Offer - Technical Configuration](https://partner.microsoft.com/en-us/dashboard/commercial-marketplace/offers/3b0884cf-abb0-46cf-a48b-55ee7245e8a9/plans/79f87324-ae57-4ec9-a648-5d6cca31b781/technicalconfiguration)
2. Specify the new version according to the versioning strategy mentioned in this README
3. Upload the `app.zip` you created by drag + dropping into the `Package file` section
4. Press `Save draft` & `Review and publish`
5. Tick everything and press `Publish` on the next screen
6. Wait until the Offer has moved into `Publisher signoff` (preview creation has succeeded)
7. [LIVE OFFER ONLY] Press the `Go live` button
