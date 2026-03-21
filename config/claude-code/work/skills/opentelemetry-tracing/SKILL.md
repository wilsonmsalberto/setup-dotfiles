---
name: opentelemetry-tracing
description: |
  OpenTelemetry instrumentation guidance.
  Use AUTOMATICALLY when:
  - Adding new API endpoints
  - Creating new services/datasources
  - Implementing complex operations
  - Debugging production issues

  Ensures proper tracing and observability.
---

# OpenTelemetry Tracing

## Purpose
Guide proper OpenTelemetry instrumentation for observability.

## When This Triggers
- Adding new GraphQL resolvers
- Creating REST datasources
- Implementing async operations
- Adding external service calls

## Tracing Basics

### Span Hierarchy
```
HTTP Request (automatic)
└── GraphQL Operation
    └── Resolver: Query.users
        └── DataSource: getUsers
            └── HTTP: GET /api/users
```

### Key Concepts
- **Trace**: Complete request journey
- **Span**: Single operation within a trace
- **Context**: Propagation of trace info

## Instrumentation Patterns

### Manual Span Creation
```typescript
import { trace } from '@opentelemetry/api';

const tracer = trace.getTracer('my-service');

async function complexOperation(data: Data) {
  return tracer.startActiveSpan('complexOperation', async (span) => {
    try {
      span.setAttribute('data.id', data.id);
      const result = await doWork(data);
      span.setStatus({ code: SpanStatusCode.OK });
      return result;
    } catch (error) {
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: error.message
      });
      span.recordException(error);
      throw error;
    } finally {
      span.end();
    }
  });
}
```

### Adding Attributes
```typescript
span.setAttribute('user.id', userId);
span.setAttribute('operation.type', 'fetch');
span.setAttribute('result.count', results.length);
```

### Recording Events
```typescript
span.addEvent('cache.miss', {
  'cache.key': cacheKey,
});
```

## GraphQL Instrumentation

### Resolver Tracing
The GraphQL server auto-instruments resolvers, but add context:
```typescript
const resolvers = {
  Query: {
    users: async (_, args, context) => {
      const span = trace.getActiveSpan();
      span?.setAttribute('query.limit', args.limit);
      // ... resolver logic
    }
  }
};
```

### DataSource Tracing
```typescript
class UsersAPI extends RESTDataSource {
  async getUser(id: string) {
    return this.trace(
      { name: 'UsersAPI.getUser', attributes: { userId: id } },
      () => this.get(`/users/${id}`)
    );
  }
}
```

## Best Practices

### Do
- Add meaningful span names (verb + noun)
- Include relevant attributes
- Record exceptions properly
- End spans in finally blocks

### Don't
- Create spans for trivial operations
- Include sensitive data in attributes
- Forget to end spans
- Over-instrument (too many spans)

## Attributes to Include

| Category | Attributes |
|----------|------------|
| User | `user.id`, `user.market` |
| Operation | `operation.name`, `operation.type` |
| Request | `http.method`, `http.url`, `http.status_code` |
| GraphQL | `graphql.operation.name`, `graphql.operation.type` |
| Cache | `cache.hit`, `cache.key` |
| Error | `error.type`, `error.message` |

## Sentry Integration

Traces are automatically sent to Sentry when configured:
```typescript
import * as Sentry from '@sentry/node';

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  tracesSampleRate: 0.1,
  integrations: [
    new Sentry.Integrations.OpenTelemetry(),
  ],
});
```

## Before Completing

- [ ] New operations have appropriate spans
- [ ] Span names are descriptive
- [ ] Relevant attributes are included
- [ ] Errors are properly recorded
- [ ] No sensitive data in traces
