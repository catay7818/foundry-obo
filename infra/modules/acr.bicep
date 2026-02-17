targetScope = 'resourceGroup'

@description('Azure region for resources')
param location string

@description('Base name for ACR resources')
@minLength(3)
@maxLength(5)
param projectName string

@description('Unique suffix for resource naming')
@minLength(5)
param uniqueSuffix string

@description('SKU for Azure Container Registry')
@allowed(['Basic', 'Standard', 'Premium'])
param sku string = 'Basic'

@description('Enable admin user access')
param adminUserEnabled bool = false

// ACR names must be 5-50 characters, alphanumeric only
// Construct name: acr + projectName (no hyphens) + uniqueSuffix
// This ensures: 3 (acr) + 3-5 (projectName) + 13 (uniqueSuffix) = 19-21 chars minimum
var acrName = toLower('acr${replace(projectName, '-', '')}${uniqueSuffix}')

// Azure Container Registry
#disable-next-line BCP035
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: sku
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    adminUserEnabled: adminUserEnabled
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        days: 7
        status: 'disabled'
      }
    }
    encryption: {
      status: 'disabled'
    }
    dataEndpointEnabled: false
    zoneRedundancy: 'Disabled'
  }
}

output acrName string = containerRegistry.name
output acrLoginServer string = containerRegistry.properties.loginServer
output acrPrincipalId string = containerRegistry.identity.principalId
