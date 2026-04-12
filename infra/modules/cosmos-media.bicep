targetScope = 'resourceGroup'

@description('Name of the existing Cosmos DB account to add media containers to')
param cosmosAccountName string

@description('Name of the existing Cosmos DB database to add media containers to')
param databaseName string

// Reference existing Cosmos DB Account
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' existing = {
  name: cosmosAccountName
}

// Reference existing Cosmos DB Database
resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' existing = {
  parent: cosmosAccount
  name: databaseName
}

// Stellar Horizons — Show container (cast, show metadata)
resource shShowContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: cosmosDatabase
  name: 'sh-show'
  properties: {
    resource: {
      id: 'sh-show'
      partitionKey: {
        paths: ['/type']
        kind: 'Hash'
      }
    }
  }
}

// Stellar Horizons — Production container (schedule, budget, scripts, approvals)
resource shProductionContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: cosmosDatabase
  name: 'sh-production'
  properties: {
    resource: {
      id: 'sh-production'
      partitionKey: {
        paths: ['/type']
        kind: 'Hash'
      }
    }
  }
}

// Stellar Horizons — Costume container
resource shCostumeContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: cosmosDatabase
  name: 'sh-costume'
  properties: {
    resource: {
      id: 'sh-costume'
      partitionKey: {
        paths: ['/type']
        kind: 'Hash'
      }
    }
  }
}

// Crown & Chaos — Show container (cast, show metadata)
resource ccShowContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: cosmosDatabase
  name: 'cc-show'
  properties: {
    resource: {
      id: 'cc-show'
      partitionKey: {
        paths: ['/type']
        kind: 'Hash'
      }
    }
  }
}

// Crown & Chaos — Production container (schedule, permits, budget, scripts, approvals)
resource ccProductionContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: cosmosDatabase
  name: 'cc-production'
  properties: {
    resource: {
      id: 'cc-production'
      partitionKey: {
        paths: ['/type']
        kind: 'Hash'
      }
    }
  }
}

// Crown & Chaos — Costume container
resource ccCostumeContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: cosmosDatabase
  name: 'cc-costume'
  properties: {
    resource: {
      id: 'cc-costume'
      partitionKey: {
        paths: ['/type']
        kind: 'Hash'
      }
    }
  }
}
