targetScope = 'resourceGroup'

@description('Azure region for resources')
param location string

@description('Base name for Foundry resources')
param projectName string

@description('Unique suffix for resource naming')
param uniqueSuffix string

@description('Name of the existing Key Vault Resource')
param keyVaultName string

@description('Name of the existing Storage Account Resource')
param storageAccountName string

@description('Name of the existing Application Insights resource')
param appInsightsName string

var foundryName = '${projectName}-foundry-${uniqueSuffix}'

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// Foundry
resource foundry 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: foundryName
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    apiProperties: {}
    customSubDomainName: foundryName
    networkAcls: {
      defaultAction: 'Allow'
    }
    allowProjectManagement: true
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: true
  }
}

// // Foundry Project
// resource foundryProject 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
//   name: 'foundry-obo-project'
//   parent: foundry
//   location: location
//   identity: {
//     type: 'SystemAssigned'
//   }
// }

output foundryName string = foundry.name
output foundryId string = foundry.id
output storageAccountName string = storageAccount.name
output keyVaultName string = keyVault.name
output appInsightsName string = appInsights.name
