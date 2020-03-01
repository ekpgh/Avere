resource "azurerm_resource_group" "storage_cache" {
  name     = "Azure-HPC-Cache"
  location = "West US 2"
}

resource "azurerm_template_deployment" "storage_cache" {
  name                = "Azure-HPC-Cache"
  resource_group_name = "${azurerm_resource_group.storage_cache.name}"
  parameters_body     = "${file("./04-Cache.Parameters.json")}"
  deployment_mode     = "Incremental"

  template_body = <<DEPLOY
  {
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
      "cacheName": {
        "type": "string",
        "minLength": 1,
        "maxLength": 80,
        "metadata": {
          "description": "Name must be between 1 and 80 characters (alphanumeric, hyphen and underscore)."
        }
      },
      "cacheThroughput": {
        "type": "string",
        "allowedValues": [
          "Standard_2G",
          "Standard_4G",
          "Standard_8G"
        ],
        "metadata": {
          "description": "The throughput (GB/s) of the cache."
        }
      },
      "cacheSize": {
        "type": "int",
        "allowedValues": [
          3072,
          6144,
          12288,
          24576,
          49152
        ],
        "metadata": {
          "description": "The size (GBs) of the cache."
        }
      },
      "storageTargets": {
        "type": "array",
        "metadata": {
          "description": "The cache storage targets."
        }
      },
      "virtualNetwork": {
        "type": "object",
        "metadata": {
          "description": "The virtual network subnet."
        }
      }
    },
    "variables": {
      "cacheApiVersion": "2019-11-01"
    },
    "functions": [
      {
        "namespace": "cache",
        "members": {
          "hasStorageTargets": {
            "parameters": [
              {
                "name": "storageTargets",
                "type": "array"
              }
            ],
            "output": {
              "type": "bool",
              "value": "[and(greater(length(parameters('storageTargets')), 0), not(equals(parameters('storageTargets')[0].name, '')))]"
            }
          }
        }
      }
    ],
    "resources": [
      {
        "type": "Microsoft.StorageCache/caches",
        "apiVersion": "[variables('cacheApiVersion')]",
        "location": "[resourceGroup().location]",
        "name": "[parameters('cacheName')]",
        "sku": {
          "name": "[parameters('cacheThroughput')]"
        },
        "properties": {
          "cacheSizeGB": "[parameters('cacheSize')]",
          "subnet": "[resourceId(parameters('virtualNetwork').resourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', parameters('virtualNetwork').name, parameters('virtualNetwork').subnetName)]"
        }
      },
      {
        "condition": "[cache.hasStorageTargets(parameters('storageTargets'))]",
        "type": "Microsoft.StorageCache/caches/storageTargets",
        "apiVersion": "[variables('cacheApiVersion')]",
        "location": "[resourceGroup().location]",
        "name": "[concat(parameters('cacheName'), '/', if(cache.hasStorageTargets(parameters('storageTargets')), parameters('storageTargets')[copyIndex()].name, 'storage'))]",
        "dependsOn": [
          "[resourceId('Microsoft.StorageCache/caches', parameters('cacheName'))]"
        ],
        "properties": {
          "targetType": "[parameters('storageTargets')[copyIndex()].type]",
          "nfs3": "[if(equals(parameters('storageTargets')[copyIndex()].type, 'nfs3'), json(concat('{\"target\": \"', parameters('storageTargets')[copyIndex()].target, '\", \"usageModel\": \"', parameters('storageTargets')[copyIndex()].usageModel, '\"}')), json('null'))]",
          "clfs": "[if(equals(parameters('storageTargets')[copyIndex()].type, 'clfs'), json(concat('{\"target\": \"', parameters('storageTargets')[copyIndex()].target, '\"}')), json('null'))]",
          "junctions": "[parameters('storageTargets')[copyIndex()].junctions]"
        },
        "copy": {
          "name": "storageTargets",
          "count": "[length(parameters('storageTargets'))]"
        }
      }
    ],
    "outputs": {
      "storageTargets": {
        "type": "array",
        "value": "[parameters('storageTargets')]"
      },
      "mountAddresses": {
        "type": "array",
        "value": "[reference(resourceId('Microsoft.StorageCache/caches', parameters('cacheName')), variables('cacheApiVersion')).mountAddresses]"
      }
    }
  }
  DEPLOY
}

output "storageTargets" {
  value = "${lookup(azurerm_template_deployment.storage_cache.outputs, "storageTargets")}"
}

output "mountAddresses" {
  value = "${lookup(azurerm_template_deployment.storage_cache.outputs, "mountAddresses")}"
}
