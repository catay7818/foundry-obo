targetScope = 'resourceGroup'

@description('Azure region for resources')
param location string

@description('Base name for resources')
param projectName string

@description('Unique suffix for resource naming')
@minLength(5)
param uniqueSuffix string

@description('Azure Container Registry login server (e.g. myacr.azurecr.io)')
param acrLoginServer string

@description('Azure Container Registry resource name (used for RBAC scoping)')
param acrName string

@description('Foundry project endpoint URL')
param projectEndpoint string

@description('Model deployment name')
param modelDeploymentName string

@description('Function App base URL')
param functionAppUrl string

@description('Tenant ID for Entra ID')
param tenantId string

@description('Client ID for the agent app registration')
param clientId string

@description('Client secret for the agent app registration')
@secure()
param clientSecret string

@description('OBO scope for the upstream API')
param oboScope string

@description('Log Analytics workspace customer ID')
param logAnalyticsWorkspaceId string

@description('Log Analytics workspace primary key')
@secure()
param logAnalyticsWorkspaceKey string

var containerGroupName = '${projectName}-aci-${uniqueSuffix}'
var containerName = '${projectName}-agent'
var imageName = '${acrLoginServer}/foundry-obo-agent:latest'

// User-assigned managed identity for ACR image pull
resource containerIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${projectName}-aci-identity-${uniqueSuffix}'
  location: location
}

// Reference existing ACR for RBAC scoping
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

// Grant the container identity AcrPull on the registry
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, containerIdentity.id, '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull
    )
    principalId: containerIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Azure Container Instance
resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: containerGroupName
  location: location
  dependsOn: [acrPullRoleAssignment]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${containerIdentity.id}': {}
    }
  }
  properties: {
    osType: 'Linux'
    restartPolicy: 'Always'
    imageRegistryCredentials: [
      {
        server: acrLoginServer
        identity: containerIdentity.id
      }
    ]
    containers: [
      {
        name: containerName
        properties: {
          image: imageName
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 2
            }
          }
          ports: [
            {
              port: 8000
              protocol: 'TCP'
            }
          ]
          environmentVariables: [
            {
              name: 'PROJECT_ENDPOINT'
              value: projectEndpoint
            }
            {
              name: 'MODEL_DEPLOYMENT_NAME'
              value: modelDeploymentName
            }
            {
              name: 'FUNCTION_APP_URL'
              value: functionAppUrl
            }
            {
              name: 'TENANT_ID'
              value: tenantId
            }
            {
              name: 'CLIENT_ID'
              value: clientId
            }
            {
              name: 'CLIENT_SECRET'
              secureValue: clientSecret
            }
            {
              name: 'OBO_SCOPE'
              value: oboScope
            }
          ]
        }
      }
    ]
    ipAddress: {
      type: 'Public'
      dnsNameLabel: '${projectName}-agent-${uniqueSuffix}'
      ports: [
        {
          port: 8000
          protocol: 'TCP'
        }
      ]
    }
    diagnostics: {
      logAnalytics: {
        workspaceId: logAnalyticsWorkspaceId
        workspaceKey: logAnalyticsWorkspaceKey
        logType: 'ContainerInsights'
      }
    }
  }
}

output containerGroupName string = containerGroup.name
output containerFqdn string = containerGroup.properties.ipAddress.fqdn
