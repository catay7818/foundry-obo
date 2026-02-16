targetScope = 'resourceGroup'

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Base name for all resources')
@minLength(3)
@maxLength(5)
param projectName string

@description('Tenant ID for Entra ID')
param tenantId string = tenant().tenantId

@description('Client ID of the Foundry agent app registration')
param foundryClientId string

@description('Client ID of the Azure Function app registration')
param functionClientId string

var uniqueSuffix = uniqueString(resourceGroup().id)
var appInsightsName = '${projectName}-appinsights'
var storageAccountName = '${replace(projectName, '-', '')}st${uniqueSuffix}'
var keyVaultName = '${projectName}-kv-${uniqueSuffix}'

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Storage Account for Function App
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowSharedKeyAccess: false // Disable key-based access
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// Key Vault for AI Foundry workspace
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      name: 'standard'
      family: 'A'
    }
    tenantId: tenant().tenantId
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enableRbacAuthorization: true
    publicNetworkAccess: 'Enabled'
  }
}

// Cosmos DB Module
module cosmosModule 'modules/cosmos.bicep' = {
  name: 'cosmos-deployment'
  params: {
    location: location
    projectName: projectName
    uniqueSuffix: uniqueSuffix
  }
}

// Function App Module
module functionModule 'modules/function.bicep' = {
  name: 'function-deployment'
  dependsOn: [appInsights, storageAccount]
  params: {
    location: location
    projectName: projectName
    uniqueSuffix: uniqueSuffix
    cosmosEndpoint: cosmosModule.outputs.cosmosEndpoint
    databaseName: cosmosModule.outputs.databaseName
    tenantId: tenantId
    functionClientId: functionClientId
    foundryClientId: foundryClientId
    appInsightsName: appInsightsName
    storageAccountName: storageAccountName
  }
}

// RBAC Module
module rbacModule 'modules/rbac.bicep' = {
  name: 'rbac-deployment'
  params: {
    cosmosAccountName: cosmosModule.outputs.cosmosAccountName
    databaseName: cosmosModule.outputs.databaseName
    functionAppPrincipalId: functionModule.outputs.functionAppPrincipalId
  }
}

module foundry 'modules/foundry.bicep' = {
  name: 'foundry-deployment'
  dependsOn: [appInsights, storageAccount, keyVault]
  params: {
    location: location
    projectName: projectName
    uniqueSuffix: uniqueSuffix
    appInsightsName: appInsightsName
    keyVaultName: keyVaultName
    storageAccountName: storageAccountName
  }
}

output cosmosAccountName string = cosmosModule.outputs.cosmosAccountName
output cosmosEndpoint string = cosmosModule.outputs.cosmosEndpoint
output functionAppName string = functionModule.outputs.functionAppName
output functionAppUrl string = functionModule.outputs.functionAppUrl
output functionAppPrincipalId string = functionModule.outputs.functionAppPrincipalId
