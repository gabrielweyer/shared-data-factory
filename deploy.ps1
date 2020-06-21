#Requires -Version 7.0
#Requires -Modules Az

<#

.SYNOPSIS
Provisions a shared and a linked Data Factories.

.DESCRIPTION
Creates the resource group(s) if required. This script will also configure the Authentication Key in the shared Integration Runtime.

.PARAMETER Location
The Azure location where we'll deploy the resources. This does not matter as we're not planning on using the resources (e.g. you'll only be charged a few cents).

Defaults to 'australiaeast'.

.PARAMETER SharedResourceGroupName
The name of the resource group where we'll deploy the **shared** Data Factory.

Can be identical to `LinkedResourceGroupName` if you want to experiment deploying both Data Factories to the same resource group.

.PARAMETER SharedFactoryName
The name of the **shared** Data Factory. Needs to be globally unique.

.PARAMETER SharedIntegrationRuntimeName
The name of the **shared** Integration Runtime.

.PARAMETER ShareIntegrationRuntimeInstallationPath
If you installed the Integration Runtime in a custom location, you'll need to provide the installation path.

.PARAMETER LinkedResourceGroupName
The name of the resource group where we'll deploy the **linked** Data Factory.

Can be identical to `SharedResourceGroupName` if you want to experiment deploying both Data Factories to the same resource group.

.PARAMETER LinkedFactoryName
The name of the **linked** Data Factory. Needs to be globally unique.

.PARAMETER UseLinkedTemplate
Use a linked template instead of a nested template to grant the Contributor role to the shared Integration Runtime.

.EXAMPLE
.\deploy.ps1 -SharedFactoryName shared-gw-adf -LinkedFactoryName linked-gw-adf

Data Factory names are globally unique. I used my initials (gw) in the names above to make them "unique". This will deploy the shared and linked Data Factories in two different resource groups.

.EXAMPLE
.\deploy.ps1 -SharedResourceGroupName data-factory-rg -LinkedResourceGroupName data-factory-rg

This will deploy the shared and the linked Data Factories in the same resource group.

.EXAMPLE
.\deploy.ps1 -SharedResourceGroupName data-factory-rg -LinkedResourceGroupName data-factory-rg -UseLinkedTemplate

This will deploy the shared and the linked Data Factories in the same resource group using a linked template.

.EXAMPLE
.\deploy.ps1 -SharedFactoryName shared-gw-adf -LinkedFactoryName linked-gw-adf -ShareIntegrationRuntimeInstallationPath 'C:\Program Files\Microsoft Integration Runtime'

The Integration Runtime installs in 'C:\Program Files\Microsoft Integration Runtime' by default.

I use the binary `dmgcmd` to set the Authentication Key. If you installed the Integration Runtime in a custom location, you'll need to provide the path.

.NOTES
You need:

- PowerShell 7 (https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows?view=powershell-7)
- Azure PowerShell (https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-4.1.0)
- The Data Factory Integration Runtime installed on the machine (https://www.microsoft.com/en-us/download/details.aspx?id=39717)

Before running this script you need to invoke `Connect-AzAccount` to sign-in and you need to select the subscription you
want to operate on.

.LINK
https://github.com/gabrielweyer/shared-data-factory

#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$Location = 'australiaeast',

    [Parameter()]
    [string]$SharedResourceGroupName = 'shared-data-factory-rg',

    [Parameter()]
    [string]$SharedFactoryName = 'shared-gw-adf',

    [Parameter()]
    [string]$SharedIntegrationRuntimeName = 'shared-integration-runtime',

    [Parameter()]
    [string]$ShareIntegrationRuntimeInstallationPath = 'C:\Program Files\Microsoft Integration Runtime',

    [Parameter()]
    [string]$LinkedResourceGroupName = 'linked-data-factory-rg',

    [Parameter()]
    [string]$LinkedFactoryName = 'linked-gw-adf',

    [Parameter()]
    [switch]$UseLinkedTemplate
)

$ErrorActionPreference = 'Stop'

Write-Host ''
Write-Host -ForegroundColor Magenta '-------------------------------------------------------------------'
Write-Host -ForegroundColor Magenta '| Create shared resource group'
Write-Host -ForegroundColor Magenta '-------------------------------------------------------------------'
Write-Host ''

$newSharedResourceGroupParameters = @{
    Location = $Location
    Name = $SharedResourceGroupName
    Force = $true
}

$createSharedResourceGroupReturn = New-AzResourceGroup @newSharedResourceGroupParameters
Write-Host -ForegroundColor DarkBlue "Created (or updated) shared resource group '$($createSharedResourceGroupReturn.ResourceGroupName)' in location '$($createSharedResourceGroupReturn.Location)'"

Write-Host ''
Write-Host -ForegroundColor Magenta '-------------------------------------------------------------------'
Write-Host -ForegroundColor Magenta '| Create shared Data Factory'
Write-Host -ForegroundColor Magenta '-------------------------------------------------------------------'
Write-Host ''

$sharedRuntimeDeploymentParameters = @{
    ResourceGroupName = $SharedResourceGroupName
    TemplateFile = Join-Path -Path $PSScriptRoot -ChildPath 'shared-integration-runtime.template.json'
    TemplateParameterObject = @{
        location = $Location
        factoryName = $SharedFactoryName
        sharedIntegrationRuntimeName = $SharedIntegrationRuntimeName
    }
}

New-AzResourceGroupDeployment @sharedRuntimeDeploymentParameters | Out-Null

Write-Host -ForegroundColor DarkBlue 'Created shared Integration Runtime'

Write-Host ''
Write-Host -ForegroundColor Magenta '-------------------------------------------------------------------'
Write-Host -ForegroundColor Magenta '| Set Authentication Key on shared Integration Runtime'
Write-Host -ForegroundColor Magenta '-------------------------------------------------------------------'
Write-Host ''

$getAuthenticationKeyParameters = @{
    ResourceGroupName = $SharedResourceGroupName
    DataFactoryName = $SharedFactoryName
    Name = $SharedIntegrationRuntimeName
}

$authenticationKey = Get-AzDataFactoryV2IntegrationRuntimeKey @getAuthenticationKeyParameters | Select-Object -ExpandProperty AuthKey1
& 'C:\Program Files\Microsoft Integration Runtime\4.0\Shared\dmgcmd.exe' -Key "$authenticationKey"

Write-Host -ForegroundColor DarkBlue 'Configured Authentication Key on shared Integration Runtime'

Write-Host ''
Write-Host -ForegroundColor Magenta '-------------------------------------------------------------------'
Write-Host -ForegroundColor Magenta '| Wait for shared Integration Runtime to come online'
Write-Host -ForegroundColor Magenta '-------------------------------------------------------------------'
Write-Host ''

Write-Host "Polling shared Integration Runtime 'State' until it becomes 'Online'. We'll poll for a bit more than two minutes before failing."
Write-Host ''
$loopCount = 0
do {
    $loopCount++;

    $getStateParameters = @{
        ResourceGroupName = $SharedResourceGroupName
        DataFactoryName = $SharedFactoryName
        Name = $SharedIntegrationRuntimeName
        Status = $true
    }

    $state = Get-AzDataFactoryV2IntegrationRuntime @getStateParameters | Select-Object -ExpandProperty State

    if ($state -ne 'Online') {
        if ($loopCount -ge 24) {
            throw "It's taking too long, bailing out. Is your self-hosted Integration Runtime installed and running?"
        }

        Write-Host "- State is '$state', sleeping for 5 seconds"
        Start-Sleep -Seconds 5
    }
} while ($state -ne 'Online')

Write-Host ''
Write-Host -ForegroundColor DarkBlue 'Shared Integration Runtime is online'

Write-Host ''
Write-Host -ForegroundColor Magenta '-------------------------------------------------------------------'
Write-Host -ForegroundColor Magenta '| Create linked resource group'
Write-Host -ForegroundColor Magenta '-------------------------------------------------------------------'
Write-Host ''

$newLinkedResourceGroupParameters = @{
    Location = $Location
    Name = $LinkedResourceGroupName
    Force = $true
}

$createLinkedResourceGroupReturn = New-AzResourceGroup @newLinkedResourceGroupParameters
Write-Host -ForegroundColor DarkBlue "Created (or updated) linked resource group '$($createLinkedResourceGroupReturn.ResourceGroupName)' in location '$($createLinkedResourceGroupReturn.Location)'"

Write-Host ''
Write-Host -ForegroundColor Magenta '-------------------------------------------------------------------'
Write-Host -ForegroundColor Magenta '| Create linked Data Factory'
Write-Host -ForegroundColor Magenta '-------------------------------------------------------------------'
Write-Host ''

$linkedDataFactoryTemplateFile = $UseLinkedTemplate ? 'linked-integration-runtime-linked-template.template.json' : 'linked-integration-runtime-nested-template.template.json';

$linkedRuntimeDeploymentParameters = @{
    ResourceGroupName = $LinkedResourceGroupName
    TemplateFile = Join-Path -Path $PSScriptRoot -ChildPath $linkedDataFactoryTemplateFile
    TemplateParameterObject = @{
        location = $Location
        linkedFactoryName = $LinkedFactoryName
        sharedFactoryResourceGroup = $SharedResourceGroupName
        sharedFactoryName = $SharedFactoryName
        sharedIntegrationRuntimeName = $SharedIntegrationRuntimeName
    }
    DeploymentDebugLogLevel = 'All'
}

New-AzResourceGroupDeployment @linkedRuntimeDeploymentParameters | Out-Null

Write-Host -ForegroundColor DarkBlue 'Created linked Integration Runtime'
