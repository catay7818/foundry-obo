targetScope = 'resourceGroup'

@description('Azure region for resources')
param location string

@description('Base name for Cosmos DB resources')
param projectName string

@description('Unique suffix for resource naming')
param uniqueSuffix string

// Cosmos DB Account
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: '${projectName}-cosmos-${uniqueSuffix}'
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    enableFreeTier: false
    disableLocalAuth: true // Enforce RBAC only
  }
}

// Cosmos DB Database
resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  parent: cosmosAccount
  name: 'DemoDatabase'
  properties: {
    resource: {
      id: 'DemoDatabase'
    }
  }
}

// Sales Container
resource salesContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: cosmosDatabase
  name: 'Sales'
  properties: {
    resource: {
      id: 'Sales'
      partitionKey: {
        paths: ['/region']
        kind: 'Hash'
      }
    }
  }
}

// HR Container
resource hrContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: cosmosDatabase
  name: 'HR'
  properties: {
    resource: {
      id: 'HR'
      partitionKey: {
        paths: ['/department']
        kind: 'Hash'
      }
    }
  }
}

// Finance Container
resource financeContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: cosmosDatabase
  name: 'Finance'
  properties: {
    resource: {
      id: 'Finance'
      partitionKey: {
        paths: ['/fiscalYear']
        kind: 'Hash'
      }
    }
  }
}

output cosmosAccountName string = cosmosAccount.name
output cosmosEndpoint string = cosmosAccount.properties.documentEndpoint
output databaseName string = cosmosDatabase.name
