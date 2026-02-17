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

@description('Name of the Azure Container Registry')
param acrName string

@allowed([ 'Enabled', 'Disabled' ])
param publicNetworkAccess string = 'Enabled'
param sku object = {
  name: 'S0'
}
param disableLocalAuth bool = false

param allowedIpRules array = []
param networkAcls object = empty(allowedIpRules) ? {
  defaultAction: 'Allow'
} : {
  ipRules: allowedIpRules
  defaultAction: 'Deny'
}


// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

var foundryName = '${projectName}-foundry-${uniqueSuffix}'
resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: foundryName
  location: location
  sku: sku
  kind: 'AIServices'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: foundryName
    networkAcls: networkAcls
    publicNetworkAccess: publicNetworkAccess
    disableLocalAuth: disableLocalAuth
  }
}


resource aiServiceConnection 'Microsoft.CognitiveServices/accounts/connections@2025-04-01-preview' = {
  name: 'aoai-connection'
  parent: account
  properties: {
    category: 'AzureOpenAI'
    authType: 'AAD'
    isSharedToAll: true
    target: account.properties.endpoints['OpenAI Language Model Instance API']
    metadata: {
      ApiType: 'azure'
      ResourceId: account.id
    }
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

// Creates the Azure Foundry connection to your Azure App Insights resource
resource appInsightConnection 'Microsoft.CognitiveServices/accounts/connections@2025-04-01-preview' = {
  name: 'app-insight-connection'
  parent: account
  properties: {
    category: 'AppInsights'
    target: appInsights.id
    authType: 'ApiKey'
    isSharedToAll: true
    credentials: {
      key: appInsights.properties.InstrumentationKey
    }
    metadata: {
      ApiType: 'Azure'
      ResourceId: appInsights.id
    }
  }
}

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

// Azure Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

// Creates the Azure Foundry connection to your Azure Storage resource
resource storageAccountConnection 'Microsoft.CognitiveServices/accounts/connections@2025-04-01-preview' = {
  name: 'storage-account-connection'
  parent: account
  properties: {
    category: 'AzureStorageAccount'
    target: storageAccount.properties.primaryEndpoints.blob
    authType: 'AAD'
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      ResourceId: storageAccount.id
    }
  }
}

var aiProjectName = 'foundry-obo-proj-${uniqueSuffix}'
resource aiProject 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  parent: account
  name: aiProjectName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: aiProjectName
    displayName: aiProjectName
  }
}

// Grant AcrPull role to AI Project identity
var acrPullRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, aiProject.id, acrPullRoleDefinitionId)
  scope: containerRegistry
  properties: {
    roleDefinitionId: acrPullRoleDefinitionId
    principalId: aiProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output foundryName string = account.name
output foundryId string = account.id
output storageAccountName string = storageAccount.name
output keyVaultName string = keyVault.name
output appInsightsName string = appInsights.name
