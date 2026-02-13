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
  params: {
    location: location
    projectName: projectName
    uniqueSuffix: uniqueSuffix
    cosmosEndpoint: cosmosModule.outputs.cosmosEndpoint
    databaseName: cosmosModule.outputs.databaseName
    tenantId: tenantId
    functionClientId: functionClientId
    foundryClientId: foundryClientId
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

output cosmosAccountName string = cosmosModule.outputs.cosmosAccountName
output cosmosEndpoint string = cosmosModule.outputs.cosmosEndpoint
output functionAppName string = functionModule.outputs.functionAppName
output functionAppUrl string = functionModule.outputs.functionAppUrl
output functionAppPrincipalId string = functionModule.outputs.functionAppPrincipalId
