# Deploying Data Factory with an existing shared Integration Runtime

## Scenario

There is a pre-existing Data Factory in **another resource group and another subscription**. This Data Factory has a self-hosted shared Integration Runtime. Other Data Factories are using this Data Factory trough a linked Integration Runtime. The self-hosted shared Integration Runtime is providing me access to on-premise databases.

When creating my linked Integration Runtime, I attempt to grant the [Contributor role on the shared Integration Runtime][shared-integration-runtime-contributor-role] to it. This is done using a nested template in a deployment resource as the shared Integration Runtime is located in another resources group and another subscription.

The first time I run the template (to create the resources), the deployment **sometimes** fails with the following error:

```plaintext
Status Message: Access denied. Unable to access shared integration runtime 'shared-integration-runtime'. Please check whether this resource has been granted permission by the shared integration runtime (Code:UnauthorizedIntegrationRuntimeAccess)
```

The second time I run the template, the deployment works. This has been consistent over a few deployment attempts. **In my template I've marked the linked Integration Runtime as depending on the deployment that grants the Contributor role but it feels the Resource Manager is not waiting for the nested template to complete**. I'm also able to reproduce this error sometimes when using a linked template.

I'm deploying the template at a resource group scope.

The deployment sometimes fails even when I deploy the shared and the linked Integration Runtime to the same resource group and subscription. You can find the reproduction steps below.

## Reproduction steps

You need to have [Azure Powershell][azure-powershell] and an [Azure subscription][azure-subscription] to run the steps.

### 1. Install the self-hosted Integration Runtime

You can't share an Integration Runtime without having it running somewhere (see [No registered nodes](#no-registered-nodes) appendix).

Download the [Integration Runtime][download-integration-runtime] (Windows only). I downloaded the version with the highest number. You can keep the default settings in the installer. At the end of the installation process, you'll get a warning if your computer is configured to sleep/hibernate. You don't need to change your Windows settings (we're not planning on using the Integration Runtime).

Once the installation is done, the Integration Runtime will prompt you for the Authentication Key. You can skip this step as the script below will set it.

### 2. Provision the resources

Replace `gw` (my initials) by a string that will make the Data Factory name globally unique.

```powershell
.\deploy.ps1 -SharedResourceGroupName shared-data-factory-rg -SharedFactoryName shared-gw-adf -SharedIntegrationRuntimeName shared-integration-runtime -LinkedResourceGroupName linked-data-factory-rg -LinkedFactoryName linked-gw-adf
```

By default the `deploy.ps1` script uses a nested template to grant the Contributor role. You can use a linked template instead by using the `-UseLinkedTemplate` switch.

You can delete the resources by calling [delete-resources.ps1](#delete-resources).

## Appendix

### Delete resources

You can call `delete-resources.ps1` to delete all the resources that were created by `deploy.ps1`:

```powershell
.\delete-resources.ps1 -SharedResourceGroupName shared-data-factory-rg -SharedFactoryName shared-gw-adf -SharedIntegrationRuntimeName shared-integration-runtime -LinkedResourceGroupName linked-data-factory-rg
```

### No registered nodes

You need to install the self-hosted Integration Runtime before attempting to share it. Otherwise you'll get the error below:

```plaintext
Status Message: Integration runtime 'shared-integration-runtime' sharing failed. Either your shared integration runtime is not registered or the version is lower than 3.8. Please register a new node or update your self-hosted integration runtime to latest version respectively. (Code:SharableIntegrationRuntimeUnSupportVersion)
```

[shared-integration-runtime-contributor-role]: https://docs.microsoft.com/en-us/azure/data-factory/create-shared-self-hosted-integration-runtime-powershell#grant-permission
[azure-powershell]: https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-4.2.0
[azure-subscription]: https://azure.microsoft.com/free/
[download-integration-runtime]: https://www.microsoft.com/en-us/download/details.aspx?id=39717
