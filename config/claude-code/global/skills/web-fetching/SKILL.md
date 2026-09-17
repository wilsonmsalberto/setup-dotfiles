---
name: web-fetching
description: Use when fetching, scraping, crawling, or searching web content, or looking up library documentation - picks between Firecrawl, Playwright, WebFetch, context7, and claude-in-chrome, and lists the Cloudflare/SPA failure modes for each.
---

# Web Fetching Strategy

## Decision Tree

```
Need web content?
├── Static page / documentation / article
│   └── Firecrawl (default) — LLM-optimized markdown, JS rendering, bypass
├── Cloudflare-protected / interactive / SPA
│   └── Playwright — full browser, can hide webdriver, custom headers
├── Simple API / raw HTML / quick check
│   └── WebFetch (built-in) — no MCP dependency, good for simple static
├── Debugging live page state
│   └── claude-in-chrome — inspect DOM, evaluate JS, NOT for fetching
└── Library docs lookup
    └── context7 — resolve-library-id → query-docs
```

## Quick Reference

| Scenario | Tool | Why |
|----------|------|-----|
| Scrape recipe/article | Firecrawl | Clean markdown, handles JS |
| Read library docs | context7 | Purpose-built, versioned |
| Cloudflare-protected site | Playwright | Real browser bypasses challenges |
| Simple static HTML | WebFetch | Built-in, no API key needed |
| Check if URL is reachable | WebFetch | Lightweight probe |
| Web/image/news search | Firecrawl | `search`, `deep_research` actions |
| Inspect live page state | claude-in-chrome | DOM + JS evaluation |
| Crawl multiple pages | Firecrawl | `crawl` + `map` actions |

## What Does NOT Work

- **WebFetch on Cloudflare sites** — returns 403 + `cf-ray` header or "Just a moment..." challenge page
- **WebFetch on SPAs** — returns empty shell (no JS execution)
- **User-Agent spoofing via fetch** — Cloudflare fingerprints beyond UA string
- **claude-in-chrome as a fetcher** — meant for debugging, not scraping

## Error Patterns to Recognize

| Symptom | Cause | Fix |
|---------|-------|-----|
| 403 + `cf-ray` header | Cloudflare blocking | Use Playwright or Firecrawl |
| "Just a moment..." in response | Cloudflare JS challenge | Use Playwright with webdriver hiding |
| Empty `<div id="root"></div>` | SPA not rendered | Use Firecrawl (renders JS) or Playwright |
| `ECONNREFUSED` | Site down or blocked | Check URL, try different tool |
| Truncated markdown | Large page | Use Firecrawl with `pageOptions.onlyMainContent: true` |

## Cloudflare Bypass (Playwright)

When Playwright is needed for Cloudflare-protected pages:

```javascript
// Hide webdriver fingerprint
await page.addInitScript(() => {
  Object.defineProperty(navigator, 'webdriver', { get: () => false });
});

// Set realistic headers
await page.setExtraHTTPHeaders({
  'Accept-Language': 'en-US,en;q=0.9',
  'Accept': 'text/html,application/xhtml+xml',
});

// Wait for challenge to resolve (if any)
await page.waitForTimeout(3000);
```

## Tool Priority

1. **Firecrawl** — first choice for any web content extraction
2. **Playwright** — when Firecrawl fails or page needs interaction
3. **WebFetch** — simple/quick checks, no external dependency
4. **claude-in-chrome** — debugging only, not fetching
