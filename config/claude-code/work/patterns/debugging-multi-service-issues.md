# Debugging Multi-Service Issues

## When to Use

When debugging issues that involve data flowing through multiple services or repositories.

## Key Principle: Check Mock Data Everywhere

Before debugging, verify what's mocked in ALL repositories:

| Repository | Check For |
|------------|-----------|
| `optimus-web` | `USE_MOCK_DATA` flags in repositories/datasources |
| `graphql` | Datasources in `src/domain/`, feature flags |

## Investigation Checklist

1. **Identify all services involved** - Trace the data flow from frontend to backend
2. **Check mock data status** - In each repository that handles the request
3. **Verify service consistency** - Different services may have different views of data
4. **Check feature flags** - Backend behavior may vary based on flags

## Common Patterns

### Different Services for Create vs Query

Some features use different backend services for mutations vs queries:

```
Create: Service A → Database
Query:  Service B → Database (may have sync delay or different data)
```

**Symptom**: Data created successfully but not found when queried.

**Investigation**: Check if create and query use the same datasource in the GraphQL server.

### Mock Data in Frontend, Real Backend

```
Frontend (optimus-web): Mock data for feature X
Backend (graphql): Real services for related feature Y
```

**Symptom**: Feature works partially but fails on cross-feature interactions.

**Investigation**: Trace which data is mocked vs real at each layer.

## Messaging System Example

The messaging system demonstrates this pattern:

| Operation | Service | Datasource |
|-----------|---------|------------|
| Create conversation | Motors Messaging | `motorsMessaging` |
| Query conversations | Chat Service | `chatService` |
| Legacy storage | Atlas | `inbox` |

**Issue**: Conversation created in Motors Messaging not found by Chat Service query.

**Root cause**: Backend data sync issue between services (not frontend bug).

## Debugging Steps

1. **Frontend**: Check if data is mocked (`USE_MOCK_DATA` flags)
2. **GraphQL**: Check which datasources handle the request
3. **Backend services**: Verify data consistency between services
4. **Feature flags**: Check if behavior varies by flag state

## When It's Not a Frontend Bug

If investigation reveals:
- Frontend correctly calls APIs
- Data exists in one backend service but not another
- Issue is service synchronization

→ **Escalate to backend team** with clear analysis of which services are out of sync.
