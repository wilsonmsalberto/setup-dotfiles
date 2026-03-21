---
name: multi-tenant-awareness
description: |
  Multi-tenant/multi-market awareness for OLX automotive projects.
  Use AUTOMATICALLY when:
  - Modifying site-specific code
  - Working with market configurations
  - Handling locale/currency/language differences
  - Modifying authentication flows

  Ensures changes work across all European markets.
---

# Multi-Tenant Awareness

## Purpose
Ensure code changes work correctly across all OLX automotive markets.

## Markets Overview

| Market | Site Code | Domain | Currency | Language |
|--------|-----------|--------|----------|----------|
| Poland | `otomotopl` | otomoto.pl | PLN | Polish |
| Romania | `autovitro` | autovit.ro | EUR | Romanian |
| Portugal | `carspt` | standvirtual.com | EUR | Portuguese |

## When This Triggers
- Modifying files with site-specific logic
- Working with translations
- Handling currency formatting
- Authentication/authorization changes
- API endpoint configurations

## Site-Specific Considerations

### Configuration Files
- `config/otomotopl/` - Poland configuration
- `config/autovitro/` - Romania configuration
- `config/carspt/` - Portugal configuration

### Environment Variables
```bash
SITE_CODE=otomotopl  # or autovitro, carspt
```

### Authentication
Each market has its own:
- Cognito user pool
- JWKS endpoint
- Session handling

### Backend Services
URLs differ per market:
- Atlas API endpoints
- CIAM service URLs
- Taxonomy service

## Testing Checklist

Before completing multi-tenant changes:

- [ ] Tested on Poland (`pnpm https-dev:pl`)
- [ ] Tested on Romania (`pnpm https-dev:ro`)
- [ ] Tested on Portugal (`pnpm https-dev:pt`)
- [ ] Translations exist for all languages
- [ ] Currency formatting works correctly
- [ ] Authentication flows work per market

## Common Patterns

### Site-Specific Imports
```typescript
// optimus-web pattern
import { getSiteConfig } from '@optimus/site-config';

const config = getSiteConfig(siteCode);
```

### GraphQL Context
```typescript
// graphql project pattern
const siteCode = context.headers['x-site-code'];
const config = getSiteConfig(siteCode);
```

### Conditional Logic
```typescript
// Avoid hardcoding market logic
// Bad
if (siteCode === 'otomotopl') { ... }

// Good - use configuration
if (config.features.hasFeatureX) { ... }
```

## Feature Flags

Use LaunchDarkly for market-specific features:
```typescript
const showFeature = await ldClient.variation(
  'feature-x',
  { key: userId, custom: { market: siteCode } },
  false
);
```

## Before Completing

- [ ] Code works for all three markets
- [ ] No hardcoded market-specific values
- [ ] Feature flags used for market differences
- [ ] Translations provided
