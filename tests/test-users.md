# Testing Scenarios

This document outlines comprehensive test scenarios for validating the Foundry Agent with OBO Cosmos DB access control demo.

## Test Users

### User A: Sales Representative
- **Container Access**: Sales only
- **Use Case**: Regional sales manager who needs sales data
- **Object ID**: `<USER_A_OBJECT_ID>` (set during deployment)

### User B: HR Manager
- **Container Access**: HR only
- **Use Case**: HR personnel who needs employee information
- **Object ID**: `<USER_B_OBJECT_ID>` (set during deployment)

### User C: Finance Analyst
- **Container Access**: Finance only
- **Use Case**: Financial analyst who needs budget and expense data
- **Object ID**: `<USER_C_OBJECT_ID>` (set during deployment)

### Admin User
- **Container Access**: Sales, HR, Finance (all containers)
- **Use Case**: System administrator with full access
- **Object ID**: `<ADMIN_OBJECT_ID>` (set during deployment)

## Test Scenarios

### Scenario 1: Basic Access Verification

#### Test 1.1: User A - Authorized Access
**Persona**: User A (Sales access)

**Test Steps**:
1. Sign in to Foundry as User A
2. Open Cosmos Data Agent
3. Ask: "What data can I access?"

**Expected Result**:
```
You have access to the following container:
- Sales
```

**Pass Criteria**: Agent correctly identifies Sales as the only accessible container

---

#### Test 1.2: User A - Query Sales Data
**Persona**: User A (Sales access)

**Test Steps**:
1. Ask: "Show me all sales data"

**Expected Result**:
```
Here are the sales records:
1. Product: Widget A, Region: West, Quantity: 150, Revenue: $15,000
2. Product: Widget B, Region: East, Quantity: 200, Revenue: $24,000
3. Product: Widget C, Region: North, Quantity: 175, Revenue: $19,250
4. Product: Widget A, Region: South, Quantity: 225, Revenue: $22,500
5. Product: Widget B, Region: West, Quantity: 300, Revenue: $36,000

Total records: 5
```

**Pass Criteria**: All 5 sales records are returned

---

#### Test 1.3: User A - Denied HR Access
**Persona**: User A (Sales access)

**Test Steps**:
1. Ask: "Show me HR data"

**Expected Result**:
```
I'm sorry, you don't have permission to access the HR container.
You only have access to: Sales
```

**Pass Criteria**: Access is denied with clear explanation

---

### Scenario 2: Filtered Queries

#### Test 2.1: Regional Sales Filter
**Persona**: User A (Sales access)

**Test Steps**:
1. Ask: "Show me sales from the West region"

**Expected Result**:
```
Sales records for West region:
1. Product: Widget A, Quantity: 150, Revenue: $15,000, Quarter: Q1
2. Product: Widget B, Quantity: 300, Revenue: $36,000, Quarter: Q2

Total: 2 records, Total Revenue: $51,000
```

**Pass Criteria**: Only West region records returned

---

#### Test 2.2: HR Department Filter
**Persona**: User B (HR access)

**Test Steps**:
1. Ask: "Show me employees in Engineering"

**Expected Result**:
```
Engineering employees:
1. Person A - Senior Engineer (Started: 2020-01-15, Status: Active)
2. Person C - Junior Engineer (Started: 2022-03-10, Status: Active)

Total: 2 employees
```

**Pass Criteria**: Only Engineering department employees returned

---

#### Test 2.3: Finance Year Filter
**Persona**: User C (Finance access)

**Test Steps**:
1. Ask: "Show me finance data for 2024"

**Expected Result**:
```
Finance records for fiscal year 2024:
1. Category: Research and Development, Amount: $180,000, Quarter: Q1, Approved: No
2. Category: Marketing, Amount: $95,000, Quarter: Q1, Approved: Yes

Total: 2 records, Total Amount: $275,000
```

**Pass Criteria**: Only 2024 fiscal year records returned

---

### Scenario 3: Cross-Container Access Tests

#### Test 3.1: Admin - Multiple Container Access
**Persona**: Admin (All access)

**Test Steps**:
1. Sign in as Admin
2. Ask: "What containers can I access?"
3. Ask: "Show me sales data"
4. Ask: "Show me HR data"
5. Ask: "Show me finance data"

**Expected Results**:
- Step 2: Lists Sales, HR, Finance
- Step 3: Returns sales records
- Step 4: Returns HR records
- Step 5: Returns finance records

**Pass Criteria**: Admin can access all three containers successfully

---

#### Test 3.2: Attempt Unauthorized Container
**Persona**: User B (HR access)

**Test Steps**:
1. Ask: "Show me finance data"
2. Ask: "Can you get sales information for me?"

**Expected Result**:
```
I don't have permission to access the Finance container. I can only access: HR

I'm unable to retrieve sales information as you don't have access to the Sales container.
```

**Pass Criteria**: Both requests denied with clear messaging

---

### Scenario 4: Query Syntax Variations

#### Test 4.1: Natural Language Query
**Persona**: User A (Sales access)

**Test Steps**:
1. Ask: "How many sales do we have?"

**Expected Result**:
```
There are 5 sales records in the database.
```

**Pass Criteria**: Agent interprets natural language and counts records

---

#### Test 4.2: Aggregation Request
**Persona**: User C (Finance access)

**Test Steps**:
1. Ask: "What's the total approved budget?"

**Expected Result**:
```
Based on approved finance records:
- 2023 Q1: $125,000 (Operating Expenses)
- 2023 Q1: $250,000 (Capital Expenditure)
- 2023 Q2: $135,000 (Operating Expenses)
- 2024 Q1: $95,000 (Marketing)

Total Approved Budget: $605,000
```

**Pass Criteria**: Agent calculates sum of approved items

---

### Scenario 5: Error Handling

#### Test 5.1: Invalid Container Name
**Persona**: User A (Sales access)

**Test Steps**:
1. Ask: "Show me data from the Products container"

**Expected Result**:
```
The 'Products' container doesn't exist. Available containers are: Sales, HR, and Finance.
You have access to: Sales
```

**Pass Criteria**: Helpful error message explaining valid containers

---

#### Test 5.2: Empty Results
**Persona**: User A (Sales access)

**Test Steps**:
1. Ask: "Show me sales from Antarctica region"

**Expected Result**:
```
No sales records found for region 'Antarctica'.
Available regions in the Sales data are: West, East, North, South
```

**Pass Criteria**: Clear message indicating no results, suggests alternatives

---

### Scenario 6: Authentication Tests

#### Test 6.1: Expired Token
**Manual API Test**:

```bash
# Use expired token
curl -X POST "https://<function-app>.azurewebsites.net/api/containers/query" \
  -H "Authorization: Bearer <expired-token>" \
  -H "Content-Type: application/json" \
  -d '{"containerName":"Sales"}'
```

**Expected Result**:
```json
{
  "success": false,
  "errorMessage": "Invalid token"
}
```

**Pass Criteria**: Returns 401 Unauthorized status

---

#### Test 6.2: Missing Token
**Manual API Test**:

```bash
# Request without authorization header
curl -X POST "https://<function-app>.azurewebsites.net/api/containers/query" \
  -H "Content-Type: application/json" \
  -d '{"containerName":"Sales"}'
```

**Expected Result**:
```json
{
  "success": false,
  "errorMessage": "Missing authorization header"
}
```

**Pass Criteria**: Returns 401 Unauthorized status

---

### Scenario 7: Data Integrity Tests

#### Test 7.1: Verify Sales Data Completeness
**Persona**: Admin (All access)

**Test Steps**:
1. Ask: "Show me all sales data"
2. Verify each record has: id, region, product, quantity, revenue, quarter

**Expected Result**: All 5 records present with complete fields

**Pass Criteria**: No missing or null fields

---

#### Test 7.2: Verify HR Data Completeness
**Persona**: Admin (All access)

**Test Steps**:
1. Ask: "Show me all HR data"
2. Verify each record has: id, department, employeeName, position, startDate, status

**Expected Result**: All 5 records present with complete fields

**Pass Criteria**: No missing or null fields

---

### Scenario 8: Performance Tests

#### Test 8.1: Response Time
**Persona**: Any user with access

**Test Steps**:
1. Ask: "Show me data" (for accessible container)
2. Measure time from request to response

**Expected Result**: Response within 3 seconds

**Pass Criteria**: Acceptable latency for demo purposes

---

#### Test 8.2: Concurrent Access
**Test Setup**: Use 3 different users simultaneously

**Test Steps**:
1. User A queries Sales
2. User B queries HR
3. User C queries Finance
(All at approximately the same time)

**Expected Result**: All requests complete successfully

**Pass Criteria**: No conflicts or errors

---

## Test Results Template

| Test ID | Scenario            | Persona | Expected Result       | Actual Result | Status | Notes |
| ------- | ------------------- | ------- | --------------------- | ------------- | ------ | ----- |
| 1.1     | Access Verification | User A  | Shows "Sales" only    |               |        |       |
| 1.2     | Query Sales         | User A  | Returns 5 records     |               |        |       |
| 1.3     | Denied HR Access    | User A  | Access denied         |               |        |       |
| 2.1     | Regional Filter     | User A  | 2 West records        |               |        |       |
| 2.2     | Dept Filter         | User B  | 2 Engineering records |               |        |       |
| ...     | ...                 | ...     | ...                   |               |        |       |

## Testing Checklist

- [ ] All test users created in Entra ID
- [ ] Object IDs recorded and updated in Function code
- [ ] Cosmos DB RBAC roles assigned correctly
- [ ] Sample data loaded into all containers
- [ ] Foundry agent configured with correct tool
- [ ] Function App deployed and running
- [ ] Application Insights enabled for logging

## Manual Testing Best Practices

1. **Test in Order**: Start with basic scenarios before advanced ones
2. **Document Results**: Record actual results in test results table
3. **Check Logs**: Review Application Insights for each test
4. **Isolate Failures**: If a test fails, retest individually
5. **Verify Data**: Confirm sample data is loaded before testing queries
6. **Test Negative Cases**: Unauthorized access is as important as authorized

## Common Issues and Solutions

### Issue: Agent returns empty results for valid query
**Solution**: Verify sample data was loaded correctly in Cosmos DB

### Issue: All users denied access
**Solution**: Check RBAC role assignments in Cosmos DB

### Issue: Token validation fails
**Solution**: Verify FoundryClientId matches app registration

### Issue: OBO token exchange fails
**Solution**: Check API permissions and admin consent for Foundry app

## Success Criteria

A successful test run should demonstrate:
1. ✅ Users can only access authorized containers
2. ✅ Queries return correct data based on filters
3. ✅ Unauthorized access is properly denied
4. ✅ Error messages are clear and helpful
5. ✅ Agent provides intelligent responses to natural language
6. ✅ All security validations work correctly
7. ✅ Performance meets acceptable thresholds

## Next Steps After Testing

1. Review Application Insights logs for patterns
2. Identify areas for improvement in agent responses
3. Consider additional containers or data types
4. Plan for production hardening (caching, rate limiting)
5. Document any customizations made during testing
