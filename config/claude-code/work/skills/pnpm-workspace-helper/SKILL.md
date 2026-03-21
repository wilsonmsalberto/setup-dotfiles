---
name: pnpm-workspace-helper
description: |
  pnpm workspace and monorepo management guidance.
  Use AUTOMATICALLY when:
  - Adding new dependencies
  - Creating new packages
  - Managing workspace relationships
  - Debugging dependency issues

  Helps navigate complex monorepo structures.
---

# pnpm Workspace Helper

## Purpose
Guide proper pnpm workspace management in monorepo projects.

## When This Triggers
- Adding dependencies to packages
- Creating new workspace packages
- Resolving dependency conflicts
- Understanding package relationships

## pnpm Workspace Basics

### Workspace Configuration
```yaml
# pnpm-workspace.yaml
packages:
  - 'packages/*'
  - 'apps/*'
```

### Adding Dependencies

```bash
# Add to specific package
pnpm add lodash --filter @optimus/common

# Add to root (dev dependency)
pnpm add -D typescript -w

# Add workspace package as dependency
pnpm add @optimus/utils --filter @optimus/dashboard --workspace
```

### Dependency Types

| Flag | Type | When to Use |
|------|------|-------------|
| (none) | dependencies | Runtime requirement |
| `-D` | devDependencies | Build/test only |
| `-O` | optionalDependencies | Nice to have |
| `--workspace` | workspace link | Internal package |

## Common Commands

### List Dependencies
```bash
# Show why package is installed
pnpm why lodash

# List all packages in workspace
pnpm ls --depth 0

# Show package dependencies
pnpm ls --filter @optimus/common
```

### Update Dependencies
```bash
# Update specific package
pnpm update lodash --filter @optimus/common

# Update all packages
pnpm update -r

# Interactive update
pnpm update -i -r
```

### Clean Install
```bash
# Remove node_modules and reinstall
pnpm store prune
rm -rf node_modules
pnpm install
```

## Nx Integration (optimus-web)

### Affected Commands
```bash
# Run tests only for affected packages
pnpm nx affected:test

# Build only affected packages
pnpm nx affected:build

# Show affected packages
pnpm nx affected:apps
pnpm nx affected:libs
```

### Dependency Graph
```bash
# Visualize dependencies
pnpm nx graph
```

## Creating New Packages

### Package Structure
```
packages/new-package/
├── package.json
├── src/
│   └── index.ts
├── tsconfig.json
└── README.md
```

### package.json Template
```json
{
  "name": "@optimus/new-package",
  "version": "0.0.1",
  "private": true,
  "main": "src/index.ts",
  "types": "src/index.ts",
  "scripts": {
    "test": "jest",
    "lint": "eslint src"
  },
  "dependencies": {},
  "devDependencies": {}
}
```

## Troubleshooting

### Common Issues

**"Peer dependency not met"**
```bash
# Check peer deps
pnpm ls --depth 1 | grep "peer"
# Install missing peer
pnpm add react@^18 --filter @optimus/component
```

**"Module not found"**
```bash
# Rebuild node_modules links
pnpm install --force
```

**"Version mismatch"**
```bash
# Use pnpm overrides in root package.json
{
  "pnpm": {
    "overrides": {
      "lodash": "^4.17.21"
    }
  }
}
```

## Best Practices

### Do
- Use workspace protocol for internal deps
- Keep dependencies in correct package
- Run `pnpm install` after pulling changes
- Use Nx affected for faster CI

### Don't
- Install global dependencies
- Duplicate dependencies across packages
- Use npm or yarn commands
- Forget to update lockfile

## Before Adding Dependencies

- [ ] Check if already installed in workspace
- [ ] Verify correct package location
- [ ] Consider bundle size impact
- [ ] Check license compatibility
- [ ] Run `pnpm install` and commit lockfile
