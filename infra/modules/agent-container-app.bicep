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

var containerAppEnvName = '${projectName}-cae-${uniqueSuffix}'
var containerAppName = '${projectName}-agent-${uniqueSuffix}'
var imageName = '${acrLoginServer}/foundry-obo-agent:latest'

// User-assigned managed identity for ACR image pull
resource containerIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${projectName}-aca-identity-${uniqueSuffix}'
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

// Container Apps Environment
resource containerAppEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: containerAppEnvName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspaceId
        sharedKey: logAnalyticsWorkspaceKey
      }
    }
  }
}

// Container App
resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  dependsOn: [acrPullRoleAssignment]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${containerIdentity.id}': {}
    }
  }
  properties: {
    environmentId: containerAppEnv.id
    configuration: {
      registries: [
        {
          server: acrLoginServer
          identity: containerIdentity.id
        }
      ]
      ingress: {
        external: true
        targetPort: 8088
        transport: 'auto'
      }
      secrets: [
        {
          name: 'client-secret'
          value: clientSecret
        }
      ]
    }
    template: {
      containers: [
        {
          name: '${projectName}-agent'
          image: imageName
          resources: {
            cpu: 1
            memory: '2Gi'
          }
          env: [
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
              secretRef: 'client-secret'
            }
            {
              name: 'OBO_SCOPE'
              value: oboScope
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

output containerAppName string = containerApp.name
output containerFqdn string = containerApp.properties.configuration.ingress.fqdn
