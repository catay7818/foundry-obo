param cosmosAccountName string
param databaseName string
param functionAppPrincipalId string

// Reference to existing Cosmos DB account
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' existing = {
  name: cosmosAccountName
}

// Cosmos DB Built-in Data Reader role definition ID
var cosmosDataReaderRoleId = '00000000-0000-0000-0000-000000000001'

// Custom role definition for container-specific access
resource salesContainerRole 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2024-05-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, 'sales-reader')
  properties: {
    roleName: 'Sales Container Reader'
    type: 'CustomRole'
    assignableScopes: [
      '${cosmosAccount.id}/dbs/${databaseName}/colls/Sales'
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

resource hrContainerRole 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2024-05-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, 'hr-reader')
  properties: {
    roleName: 'HR Container Reader'
    type: 'CustomRole'
    assignableScopes: [
      '${cosmosAccount.id}/dbs/${databaseName}/colls/HR'
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

resource financeContainerRole 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2024-05-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, 'finance-reader')
  properties: {
    roleName: 'Finance Container Reader'
    type: 'CustomRole'
    assignableScopes: [
      '${cosmosAccount.id}/dbs/${databaseName}/colls/Finance'
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

// Assign Function App managed identity full read access (for OBO flow)
resource functionAppRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, functionAppPrincipalId, cosmosDataReaderRoleId)
  properties: {
    roleDefinitionId: '${cosmosAccount.id}/sqlRoleDefinitions/${cosmosDataReaderRoleId}'
    principalId: functionAppPrincipalId
    scope: cosmosAccount.id
  }
}

output salesRoleId string = salesContainerRole.id
output hrRoleId string = hrContainerRole.id
output financeRoleId string = financeContainerRole.id
