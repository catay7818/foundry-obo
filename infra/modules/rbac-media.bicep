param cosmosAccountName string
param databaseName string
param functionAppPrincipalId string

// Reference to existing Cosmos DB account
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' existing = {
  name: cosmosAccountName
}

// Cosmos DB Built-in Data Contributor role definition ID (read + write)
var cosmosDataContributorRoleId = '00000000-0000-0000-0000-000000000002'

// Custom role definition — Stellar Horizons Show container
resource shShowContainerRole 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2024-05-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, 'sh-show-reader')
  properties: {
    roleName: 'SH Show Container Reader'
    type: 'CustomRole'
    assignableScopes: [
      '${cosmosAccount.id}/dbs/${databaseName}/colls/sh-show'
    ]
    permissions: [
      {
        dataActions: [
          'Microsoft.DocumentDB/databaseAccounts/readMetadata'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/read'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/executeQuery'
        ]
        notDataActions: []
      }
    ]
  }
}

// Custom role definition — Stellar Horizons Production container
resource shProductionContainerRole 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2024-05-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, 'sh-production-reader')
  properties: {
    roleName: 'SH Production Container Reader'
    type: 'CustomRole'
    assignableScopes: [
      '${cosmosAccount.id}/dbs/${databaseName}/colls/sh-production'
    ]
    permissions: [
      {
        dataActions: [
          'Microsoft.DocumentDB/databaseAccounts/readMetadata'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/read'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/executeQuery'
        ]
        notDataActions: []
      }
    ]
  }
}

// Custom role definition — Stellar Horizons Costume container
resource shCostumeContainerRole 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2024-05-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, 'sh-costume-reader')
  properties: {
    roleName: 'SH Costume Container Reader'
    type: 'CustomRole'
    assignableScopes: [
      '${cosmosAccount.id}/dbs/${databaseName}/colls/sh-costume'
    ]
    permissions: [
      {
        dataActions: [
          'Microsoft.DocumentDB/databaseAccounts/readMetadata'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/read'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/executeQuery'
        ]
        notDataActions: []
      }
    ]
  }
}

// Custom role definition — Crown & Chaos Show container
resource ccShowContainerRole 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2024-05-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, 'cc-show-reader')
  properties: {
    roleName: 'CC Show Container Reader'
    type: 'CustomRole'
    assignableScopes: [
      '${cosmosAccount.id}/dbs/${databaseName}/colls/cc-show'
    ]
    permissions: [
      {
        dataActions: [
          'Microsoft.DocumentDB/databaseAccounts/readMetadata'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/read'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/executeQuery'
        ]
        notDataActions: []
      }
    ]
  }
}

// Custom role definition — Crown & Chaos Production container
resource ccProductionContainerRole 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2024-05-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, 'cc-production-reader')
  properties: {
    roleName: 'CC Production Container Reader'
    type: 'CustomRole'
    assignableScopes: [
      '${cosmosAccount.id}/dbs/${databaseName}/colls/cc-production'
    ]
    permissions: [
      {
        dataActions: [
          'Microsoft.DocumentDB/databaseAccounts/readMetadata'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/read'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/executeQuery'
        ]
        notDataActions: []
      }
    ]
  }
}

// Custom role definition — Crown & Chaos Costume container
resource ccCostumeContainerRole 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2024-05-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, 'cc-costume-reader')
  properties: {
    roleName: 'CC Costume Container Reader'
    type: 'CustomRole'
    assignableScopes: [
      '${cosmosAccount.id}/dbs/${databaseName}/colls/cc-costume'
    ]
    permissions: [
      {
        dataActions: [
          'Microsoft.DocumentDB/databaseAccounts/readMetadata'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/read'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/executeQuery'
        ]
        notDataActions: []
      }
    ]
  }
}

// Assign Function App managed identity full read/write access for seeding
resource functionAppRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, functionAppPrincipalId, cosmosDataContributorRoleId, 'media')
  properties: {
    roleDefinitionId: '${cosmosAccount.id}/sqlRoleDefinitions/${cosmosDataContributorRoleId}'
    principalId: functionAppPrincipalId
    scope: cosmosAccount.id
  }
}

output shShowRoleId string = shShowContainerRole.id
output shProductionRoleId string = shProductionContainerRole.id
output shCostumeRoleId string = shCostumeContainerRole.id
output ccShowRoleId string = ccShowContainerRole.id
output ccProductionRoleId string = ccProductionContainerRole.id
output ccCostumeRoleId string = ccCostumeContainerRole.id
