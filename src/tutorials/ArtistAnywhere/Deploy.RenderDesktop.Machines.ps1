﻿# Before running this Azure resource deployment script, make sure that the Azure CLI is installed locally.
# You must have version 2.1.0 (or greater) of the Azure CLI installed for this script to run properly.
# The current Azure CLI release is available at http://docs.microsoft.com/cli/azure/install-azure-cli

param (
	# Set a naming prefix for the Azure resource groups that are created by this deployment script
	[string] $resourceGroupNamePrefix,

	# Set to 1 or more Azure region names (http://azure.microsoft.com/global-infrastructure/regions)
	[string[]] $computeRegionNames,

	# Set to the Azure Networking resources (Virtual Network, Private DNS, etc.) for compute regions
	[object[]] $computeNetworks,

	# Set to the Render Manager host address in each of the compute regions
	[string[]] $renderManagers,

	# Set to the Render Desktop Shared Image Gallery (SIG) image verion
	[object] $imageVersion

)

$templateDirectory = $PSScriptRoot
if (!$templateDirectory) {
	$templateDirectory = $using:templateDirectory
}

Import-Module "$templateDirectory\Deploy.psm1"

$moduleDirectory = "RenderDesktop"

# 11 - Desktop Machines
$renderDesktops = @()
$moduleName = "11 - Desktop Machines"
New-TraceMessage $moduleName $true
for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
	New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
	$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Desktop"
	$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
	if (!$resourceGroup) { return }

	$templateResources = "$templateDirectory\$moduleDirectory\11-Desktop.Machines.json"
	$templateParameters = (Get-Content "$templateDirectory\$moduleDirectory\11-Desktop.Machines.Parameters.json" -Raw | ConvertFrom-Json).parameters
	$machineExtensionScript = Get-MachineExtensionScript "$templateDirectory\$moduleDirectory\11-Desktop.Machines.ps1" $renderManagers[$computeRegionIndex]
	if ($templateParameters.renderDesktop.value.imageVersionId -eq "") {
		$templateParameters.renderDesktop.value.imageVersionId = $imageVersion.id
	}
	if ($templateParameters.renderDesktop.value.logAnalyticsWorkspaceId -eq "") {
		$templateParameters.renderDesktop.value.logAnalyticsWorkspaceId = $using:logAnalyticsWorkspaceId
	}
	if ($templateParameters.renderDesktop.value.logAnalyticsWorkspaceKey -eq "") {
		$templateParameters.renderDesktop.value.logAnalyticsWorkspaceKey = $using:logAnalyticsWorkspaceKey
	}
	if ($templateParameters.renderDesktop.value.machineExtensionScript -eq "") {
		$templateParameters.renderDesktop.value.machineExtensionScript = $machineExtensionScript
	}
	if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
		$templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
	}
	if ($templateParameters.virtualNetwork.value.name -eq "") {
		$templateParameters.virtualNetwork.value.name = $computeNetworks[$computeRegionIndex].name
	}
	$templateParameters = ($templateParameters | ConvertTo-Json -Compress -Depth 4).Replace('"', '\"')
	$groupDeployment = az group deployment create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters | ConvertFrom-Json
	if (!$groupDeployment) { return }

	$renderDesktops += $groupDeployment.properties.outputs.renderDesktops.value
	New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
}
New-TraceMessage $moduleName $false

Write-Output -InputObject $renderDesktops -NoEnumerate
