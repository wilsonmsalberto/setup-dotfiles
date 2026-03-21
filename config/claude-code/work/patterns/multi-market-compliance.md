# Multi-Market Compliance Pattern

## Rule

**Never hardcode market-specific values as defaults.**

This application serves three European markets with different languages and URL structures:

| Market | Site Code | Account URL |
|--------|-----------|-------------|
| Poland | `otomotopl` | `/mojekonto/` |
| Romania | `autovitro` | `/contul-meu/` |
| Portugal | `carspt` | `/contapessoal/` |

## Common Violations

### Hardcoded Polish URLs

```typescript
// WRONG - Polish URL as default
const accountUrl = process.env.atlasUrls?.account ?? "/mojekonto/";

// CORRECT - Market-neutral fallback
const accountUrl = process.env.atlasUrls?.account ?? "";
```

### Hardcoded Currency

```typescript
// WRONG - Polish currency as default
const currency = config?.currency ?? "PLN";

// CORRECT - No assumption about market
const currency = config?.currency ?? "";
```

### Hardcoded Translations

```typescript
// WRONG - Polish text as fallback
const label = t("save-button") ?? "Zapisz";

// CORRECT - Use translation system properly
const label = t("save-button", null, { default: "Save" });
```

## How to Access Market-Specific Values

### 1. Atlas URLs (Most Common)

```typescript
// URLs are injected at build time from config/{siteCode}/default.js
const accountUrl = process.env.atlasUrls?.account ?? "";
const messagesUrl = process.env.atlasUrls?.messages ?? "";
```

### 2. Navigation Routes

```typescript
import { getUrl } from "@optimus/containers/src/navigation/utils/get-url";

// Uses routes from config/navigation/routes.{siteCode}.json
const accountUrl = getUrl("account") ?? "";
```

### 3. Site Configuration

```typescript
import { getSiteConfig } from "@optimus/site-config";

const config = getSiteConfig(siteCode);
const currency = config.currency;
const locale = config.locale;
```

## Configuration File Locations

Market-specific configurations live in:

```
config/
├── otomotopl/default.js     # Poland
├── autovitro/default.js     # Romania
├── carspt/default.js        # Portugal
```

Navigation routes:

```
packages/common/constants/navigation/
├── routes.otomotopl.json
├── routes.autovitro.json
├── routes.carspt.json
```

## Testing Checklist

Before completing any feature:

- [ ] Test on Poland (`pnpm https-dev:pl`)
- [ ] Test on Romania (`pnpm https-dev:ro`)
- [ ] Test on Portugal (`pnpm https-dev:pt`)
- [ ] No hardcoded market-specific values
- [ ] All user-facing text uses translation system

## Quick Reference

| Need | Use |
|------|-----|
| Account/profile URL | `process.env.atlasUrls?.account` |
| Messages URL | `process.env.atlasUrls?.messages` |
| Navigation route | `getUrl("routeName")` |
| Currency | Site config or GraphQL response |
| User-facing text | `useTranslation` hook |
