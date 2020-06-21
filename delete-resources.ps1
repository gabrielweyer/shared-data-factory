#Requires -Version 7.0
#Requires -Modules Az

<#

.SYNOPSIS
Deletes the resource group containing the shared and the linked Data Factory.

.DESCRIPTION
A shared Data Factory cannot be deleted until its shared Integration Runtimes are deleted.

This scripts deletes the shared Integration Runtime and then it deletes the resource group.

.PARAMETER ResourceGroupName
The name of the resource group.

.PARAMETER SharedFactoryName
The name of the Data Factory.

.PARAMETER SharedIntegrationRuntimeName
The name of the shared Integration Runtime.

.EXAMPLE
.\delete-resources.ps1 -SharedResourceGroupName shared-data-factory-rg -SharedFactoryName shared-gw-adf -SharedIntegrationRuntimeName shared-integration-runtime -LinkedResourceGroupName linked-data-factory-rg

Delete all the resources when the shared and linked Data Factories are located in different resource groups.

.EXAMPLE
.\delete-resources.ps1 -SharedResourceGroupName data-factory-rg -SharedFactoryName shared-gw-adf -SharedIntegrationRuntimeName shared-integration-runtime -LinkedResourceGroupName data-factory-rg

Delete all the resources when the shared and linked Data Factories are located in the same resource group.

.NOTES
You need:

- PowerShell 7 (https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows?view=powershell-7)
- Azure PowerShell (https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-4.1.0)

Before running this script you need to invoke `Connect-AzAccount` to sign-in and you need to select the subscription you
want to operate on.

.LINK
https://github.com/gabrielweyer/shared-data-factory

#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$SharedResourceGroupName = 'shared-data-factory-rg',

    [Parameter()]
    [string]$SharedFactoryName = 'shared-gw-adf',

    [Parameter()]
    [string]$SharedIntegrationRuntimeName = 'shared-integration-runtime',

    [Parameter()]
    [string]$LinkedResourceGroupName = 'linked-data-factory-rg'
)

$ErrorActionPreference = 'Stop'

Write-Host ''
Write-Host -ForegroundColor Magenta '-------------------------------------------------------------------'
Write-Host -ForegroundColor Magenta '| Delete shared Integration Runtime'
Write-Host -ForegroundColor Magenta '-------------------------------------------------------------------'
Write-Host ''

$removeSharedIntegrationRuntimeParameters = @{
    ResourceGroupName = $SharedResourceGroupName
    DataFactoryName = $SharedFactoryName
    Name = $SharedIntegrationRuntimeName
    Force = $true
}

Remove-AzDataFactoryV2IntegrationRuntime @removeSharedIntegrationRuntimeParameters

Write-Host -ForegroundColor DarkBlue 'Deleted shared Integration Runtime'

Write-Host ''
Write-Host -ForegroundColor Magenta '-------------------------------------------------------------------'
Write-Host -ForegroundColor Magenta '| Delete shared resource group'
Write-Host -ForegroundColor Magenta '-------------------------------------------------------------------'
Write-Host ''

$removeSharedResourceGroupParameters = @{
    Name = $SharedResourceGroupName
    Force = $true
}

Remove-AzResourceGroup @removeSharedResourceGroupParameters | Out-Null

Write-Host -ForegroundColor DarkBlue 'Deleted shared resource group'

Write-Host ''
Write-Host -ForegroundColor Magenta '-------------------------------------------------------------------'
Write-Host -ForegroundColor Magenta '| Delete linked resource group'
Write-Host -ForegroundColor Magenta '-------------------------------------------------------------------'
Write-Host ''

if ($SharedResourceGroupName -eq $LinkedResourceGroupName) {
    Write-Host -ForegroundColor DarkBlue 'The linked resource group has already been deleted as it is the same than the shared resource group'
} else {
    $removeLinkedResourceGroupParameters = @{
        Name = $LinkedResourceGroupName
        Force = $true
    }
    
    Remove-AzResourceGroup @removeLinkedResourceGroupParameters | Out-Null
    
    Write-Host -ForegroundColor DarkBlue 'Deleted linked resource group'
}

