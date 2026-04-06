targetScope = 'resourceGroup'

@description('Azure region for resources')
param location string

@description('Base name for resources')
param projectName string

@description('Unique suffix for resource naming')
@minLength(1)
param uniqueSuffix string

@description('URL of the deployed agent container (ACI)')
param agentUrl string

var staticWebAppName = '${projectName}-swa-${uniqueSuffix}'

resource staticWebApp 'Microsoft.Web/staticSites@2024-04-01' = {
  name: staticWebAppName
  location: location
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {
    stagingEnvironmentPolicy: 'Disabled'
    allowConfigFileUpdates: true
    provider: 'None'
    buildProperties: {
      appLocation: 'ui'
      outputLocation: 'dist'
      appBuildCommand: 'npm run build'
    }
  }
}

// App settings surface the agent URL to the static site's linked API tier
// and as a named constant for build-time substitution via SWA CLI / CI
resource staticWebAppSettings 'Microsoft.Web/staticSites/config@2024-04-01' = {
  parent: staticWebApp
  name: 'appsettings'
  properties: {
    VITE_AGENT_SERVER_URL: agentUrl
  }
}

output staticWebAppName string = staticWebApp.name
output staticWebAppUrl string = 'https://${staticWebApp.properties.defaultHostname}'

@secure()
output deploymentToken string = staticWebApp.listSecrets().properties.apiKey
