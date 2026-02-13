# Architecture Overview

## System Components

This demonstration showcases a secure, multi-tier architecture for container-level access control in Cosmos DB using On-Behalf-Of (OBO) authentication with Microsoft Foundry agents.

### High-Level Architecture

```
┌─────────────┐
│   User      │
│  (Browser)  │
└──────┬──────┘
       │ 1. User Token
       │
┌──────▼────────────┐
│ Foundry Agent     │
│ (UI Interface)    │
└──────┬────────────┘
       │ 2. API Call + User Token
       │
┌──────▼─────────────────────────┐
│ Azure Function                 │
│ ┌──────────────────────────┐   │
│ │ Token Validation         │   │
│ └────────┬─────────────────┘   │
│          │                      │
│ ┌────────▼─────────────────┐   │
│ │ Authorization Check      │   │
│ │ (User → Container Map)   │   │
│ └────────┬─────────────────┘   │
│          │                      │
│ ┌────────▼─────────────────┐   │
│ │ OBO Token Exchange       │   │
│ │ (User Token → Service)   │   │
│ └────────┬─────────────────┘   │
└──────────┼─────────────────────┘
           │ 3. Service Token
           │
    ┌──────▼──────────────┐
    │ Cosmos DB           │
    │ ┌─────────────────┐ │
    │ │ Sales Container │ │
    │ └─────────────────┘ │
    │ ┌─────────────────┐ │
    │ │ HR Container    │ │
    │ └─────────────────┘ │
    │ ┌─────────────────┐ │
    │ │ Finance Contain.│ │
    │ └─────────────────┘ │
    └─────────────────────┘
```

## Authentication Flow

### 1. User Authentication
- User authenticates with Azure AD/Entra ID
- Receives JWT token with claims (OID, scopes, audience)

### 2. Foundry Agent Request
- Agent sends user's token to Azure Function
- Token is passed in `Authorization: Bearer <token>` header

### 3. Token Validation (Azure Function)
- Validates token signature and claims
- Extracts user Object ID (OID)
- Verifies token audience matches Foundry app registration

### 4. Authorization Check
- Looks up user's container permissions in mapping
- Denies request if user lacks access to requested container
- Proceeds if authorized

### 5. OBO Token Exchange
- Azure Function exchanges user token for service token
- Service token has permissions to access Cosmos DB
- Uses Function App's managed identity

### 6. Cosmos DB Query
- Function queries specified container with service token
- Cosmos DB validates service token and RBAC permissions
- Returns results to Function

### 7. Response
- Function returns data to Foundry agent
- Agent presents results to user

## Security Layers

### Layer 1: User Authentication
- **Provider**: Azure AD/Entra ID
- **Mechanism**: OAuth 2.0 / OpenID Connect
- **Validation**: JWT signature, expiration, audience

### Layer 2: Function Authorization
- **Provider**: Custom middleware in Azure Function
- **Mechanism**: User-to-container mapping
- **Enforcement**: Pre-query authorization check

### Layer 3: OBO Token Exchange
- **Provider**: Microsoft Identity Platform
- **Mechanism**: On-Behalf-Of flow
- **Purpose**: Convert user context to service context

### Layer 4: Cosmos DB RBAC
- **Provider**: Cosmos DB SQL RBAC
- **Mechanism**: Container-scoped role assignments
- **Granularity**: Per-container, per-user

## Data Flow Example

### Scenario: User A requests Sales data

```
1. User A → Foundry Agent
   Request: "Show me sales data"

2. Foundry Agent → Azure Function
   POST /api/containers/query
   Authorization: Bearer eyJ0eXAiOiJKV1Qi...
   Body: { "containerName": "Sales" }

3. Azure Function
   a. Validates token → Extract OID: "user-a-oid"
   b. Check permissions: user-a-oid → ["Sales"] ✓
   c. Exchange token for Cosmos DB access
   d. Query: SELECT * FROM c

4. Cosmos DB
   a. Validate service token
   b. Check RBAC: Function has read access to Sales ✓
   c. Return results

5. Azure Function → Foundry Agent
   Response: { "success": true, "data": [...], "itemCount": 5 }

6. Foundry Agent → User A
   "Here are the sales records: [formatted data]"
```

### Scenario: User A requests HR data (denied)

```
1. User A → Foundry Agent
   Request: "Show me HR data"

2. Foundry Agent → Azure Function
   POST /api/containers/query
   Authorization: Bearer eyJ0eXAiOiJKV1Qi...
   Body: { "containerName": "HR" }

3. Azure Function
   a. Validates token → Extract OID: "user-a-oid"
   b. Check permissions: user-a-oid → ["Sales"] ✗
   c. DENY REQUEST

4. Azure Function → Foundry Agent
   Response: {
     "success": false,
     "errorMessage": "Access denied to container 'HR'"
   }

5. Foundry Agent → User A
   "I'm sorry, you don't have permission to access HR data."
```

## Key Design Decisions

### 1. Container-Level Granularity
- **Why**: Balances security with simplicity
- **Alternative**: Row-level security (more complex, less performant)
- **Tradeoff**: Users get all-or-nothing access to containers

### 2. Function-Based Authorization
- **Why**: Centralized policy enforcement point
- **Alternative**: Direct Cosmos DB access with RBAC only
- **Benefit**: Flexible authorization logic, audit logging

### 3. No Token Caching
- **Why**: Simplicity for demonstration purposes
- **Impact**: Slight performance overhead per request
- **Production**: Implement distributed cache (Redis)

### 4. Managed Identity for Function
- **Why**: No credential management required
- **Security**: Automatic rotation, no secrets in code
- **Limitation**: Requires Azure-hosted deployment

## Cosmos DB RBAC Model

### Built-in Roles
- **Cosmos DB Data Reader**: Read access to all containers
- **Cosmos DB Data Contributor**: Read/write access to all containers

### Custom Roles (This Demo)
- **Sales Container Reader**: Read-only access to Sales container
- **HR Container Reader**: Read-only access to HR container
- **Finance Container Reader**: Read-only access to Finance container

### Role Assignment Scope
```
Cosmos Account
└── Database: DemoDatabase
    ├── Container: Sales
    │   └── Role Assignment: User A → Sales Container Reader
    ├── Container: HR
    │   └── Role Assignment: User B → HR Container Reader
    └── Container: Finance
        └── Role Assignment: User C → Finance Container Reader
```

## Monitoring and Observability

### Application Insights Integration
- **Function Logs**: All requests, authorization decisions
- **Performance Metrics**: Request duration, token validation time
- **Error Tracking**: Failed auth, denied access, query errors

### Audit Trail
- **Who**: User OID from token
- **What**: Container accessed, query executed
- **When**: Timestamp from Application Insights
- **Result**: Success/failure, error messages

## Scalability Considerations

### Current Design (Demo)
- **User Mapping**: In-memory dictionary
- **Limitation**: Not shared across Function instances

### Production Recommendations
1. **User Mapping**: Store in Azure Table Storage or Cosmos DB
2. **Token Cache**: Use Redis for OBO tokens
3. **Function Scaling**: Enable auto-scale based on load
4. **Cosmos DB**: Provision adequate RU/s for query load

## Security Considerations

### Threats Mitigated
- ✓ Unauthorized data access (RBAC enforcement)
- ✓ Token replay attacks (token validation, expiration)
- ✓ Privilege escalation (container-scoped permissions)
- ✓ Credential exposure (managed identity, no secrets)

### Remaining Considerations
- ⚠ Token lifetime: Users retain access until token expires
- ⚠ Query injection: Validate/sanitize user queries in production
- ⚠ Rate limiting: Add throttling to prevent abuse

## Future Enhancements

1. **Dynamic Role Management**: UI for admins to assign permissions
2. **Row-Level Security**: Filter results based on user attributes
3. **Query Auditing**: Log all queries for compliance
4. **Multi-Region**: Deploy Functions and Cosmos DB globally
5. **Advanced Analytics**: AI-powered data insights through Foundry
