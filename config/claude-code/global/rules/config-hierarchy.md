# Configuration Hierarchy Rules

## Tier Structure

```
~/.claude/                   GLOBAL   → Universal, all projects
~/Work/.claude/              WORK     → Shared OLX automotive (optimus-web + graphql)
~/Work/optimus-web/.claude/  PROJECT  → Next.js frontend only
~/Work/graphql/.claude/      PROJECT  → GraphQL backend only
~/Playground/.claude/        PLAY     → Relaxed experimentation
~/Playground/curino/.claude/  PROJECT  → React Native recipe app
```

Settings inherit downward. Lower tiers override higher tiers.

## Where Things Belong

### GLOBAL (`~/.claude/`)
- Security hooks (secret detection, dangerous pattern blocking)
- Tool preferences (Grep over grep, Read over cat)
- TypeScript standards, code cleanup rules
- Universal plugins (typescript-lsp, github, pr-review-toolkit, etc.)
- Desktop notification and PreCompact hooks

### WORK (`~/Work/.claude/`)
- Multi-tenant/multi-market patterns
- Cross-repo debugging patterns
- Deprecated API guards (OLX-specific)
- Agent Teams enablement
- Skills shared between frontend + backend

### PROJECT
- Project-specific hooks (lint, export validation, schema validation)
- Project-specific skills and agents
- Feature context files
- Package-specific permissions

### PLAYGROUND (`~/Playground/.claude/`)
- Relaxed overrides (console.log allowed, broader install permissions)
- Experiment-scoped plugins (firebase, frontend-mobile-development)

## Decision Checklist for New Config

Before adding anything, ask:

| Question | If Yes → Place Here |
|----------|-------------------|
| Does this apply to ALL projects everywhere? | `~/.claude/` |
| Does this apply to both optimus-web AND graphql? | `~/Work/.claude/` |
| Is this frontend-only? | `~/Work/optimus-web/.claude/` |
| Is this backend-only? | `~/Work/graphql/.claude/` |
| Is this for experimentation/learning? | `~/Playground/.claude/` |

## Anti-Patterns to Avoid

1. **Plan files in global** — Plans are always project-specific. Use project `.claude/plans/`.
2. **Project-specific plugins at global** — Scope plugins to the tier that uses them.
3. **Permissions that fight hooks** — Don't allow `Bash(grep:*)` globally while a hook suggests using Grep tool.
4. **Project paths in global settings** — No `additionalDirectories` pointing to specific project files at the global level.
5. **Sync hooks that can be async** — Linting, formatting, and validation hooks should use `"async": true` unless they must block.
6. **Duplicate reference material in CLAUDE.md** — If a skill provides the documentation, CLAUDE.md should point to the skill, not repeat the content.

## Hook Placement Guide

| Hook Type | Global | Work | Project |
|-----------|--------|------|---------|
| Security (secrets, dangerous code) | Yes | — | — |
| Tool suggestions (use Grep not grep) | Yes | — | — |
| Deprecated API guard | — | Yes | — |
| Lint on edit | — | — | Yes |
| Schema validation | — | — | Yes (graphql) |
| Feature context loading | — | — | Yes |
| Skill/agent suggestion | — | — | Yes |
| PreCompact (context preservation) | Yes (generic) | — | Yes (project-specific) |
| Notification (desktop alert) | Yes | — | — |
| Cleanup reminder (Stop) | Yes | — | — |
