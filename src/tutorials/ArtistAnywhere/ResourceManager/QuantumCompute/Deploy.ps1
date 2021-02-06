param (
    $resourceGroup = @{
        "name" = ""
        "regionName" = "WestUS"     # https://azure.microsoft.com/global-infrastructure/geographies/
    },
    $quantumWorkspace = @{          # https://docs.microsoft.com/azure/quantum/overview-azure-quantum
        "name" = ""
        "providers" = @(
            @{
                "providerId" = "Microsoft"
                "providerSku" = "DZH3178M639F"
            }
        )
    },
    $storageAccount = @{
        "name" = ""
        "resourceGroupName" = ""
    }
)

az group create --name $resourceGroup.name --location $resourceGroup.regionName

$templateFile = "$PSScriptRoot/Template.json"
$templateParameters = "$PSScriptRoot/Template.Parameters.json"

$templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
$templateConfig.parameters.quantumWorkspace.value = $quantumWorkspace
$templateConfig.parameters.storageAccount.value = $storageAccount
$templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

az deployment group create --resource-group $resourceGroup.name --template-file $templateFile --parameters $templateParameters
