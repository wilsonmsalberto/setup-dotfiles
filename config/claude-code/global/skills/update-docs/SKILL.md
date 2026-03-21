---
name: update-docs
description: |
  Update project documentation after completing features or patterns.
  Use MANUALLY when:
  - Completing a feature implementation
  - Establishing a new codebase pattern
  - Adding feature flags to existing code
  - Making significant architectural changes
  - Making decisions that should be documented for future reference

  Updates .claude/context/, .claude/patterns/, and cleans up plans.
---

# Update Documentation

Update project documentation after completing features, establishing patterns, or making decisions.

## When to Update Docs

ALWAYS update documentation when:

1. **Feature implementation complete** - Document the feature in `.claude/context/`
2. **New pattern established** - Document in `.claude/patterns/`
3. **Architectural decision made** - Record the decision and reasoning
4. **Deprecated API discovered** - Add to `.claude/patterns/deprecated-apis.md`
5. **Plan completed** - Delete from `.claude/plans/`
6. **Code quality issue found and fixed** - Update relevant patterns

## Documentation Structure

| Location | Purpose | When to Update |
|----------|---------|----------------|
| `.claude/context/` | Feature-specific context for ongoing work | New features, POCs |
| `.claude/patterns/` | Reusable codebase patterns | New patterns established |
| `.claude/plans/` | Implementation plans | Delete when feature complete |
| `CLAUDE.md` | Project overview | Rarely, only for major changes |

## Workflow

### Step 1: Audit Existing Documentation

**ALWAYS scan existing docs first** to find issues:

```bash
ls -la .claude/context/ .claude/patterns/ .claude/plans/
```

Look for:

- **Outdated info** - References to deleted files, old patterns, removed features
- **Conflicts** - Same topic documented differently in multiple places
- **Redundancy** - Information duplicated across files
- **Stale plans** - Completed work still in `.claude/plans/`

### Step 2: Clean Up

Before adding new content:

1. **Delete completed plans** from `.claude/plans/`
2. **Remove outdated sections** from existing docs
3. **Consolidate duplicates** - Pick one location, delete the other
4. **Update stale references** - File paths, function names, patterns

### Step 3: Document What Was Learned

Capture everything learned during implementation **and from user feedback during the conversation**:

1. **Technical decisions** - Why a particular approach was chosen
2. **Patterns used** - How existing patterns were applied
3. **New patterns established** - Extract to `.claude/patterns/`
4. **Deprecated APIs found** - Add to deprecated-apis.md
5. **Caveats discovered** - Document gotchas for future reference
6. **Duplication decisions** - When duplication was intentionally kept vs extracted
7. **User corrections/preferences** - Patterns or restrictions the user insinuated or explicitly stated
8. **ESLint rules encountered** - Document rules that affected implementation
9. **Existing components discovered** - Components that should be reused instead of recreated
10. **File organization patterns** - Directory structures the user prefers

### Step 4: Update or Create

1. **Identify what changed**
   - List modified/created files
   - Note patterns established
   - Check for feature flags used
   - Record architectural decisions

2. **Determine documentation type**
   - Feature context → `.claude/context/{feature}.md`
   - Reusable pattern → `.claude/patterns/{pattern}.md`

3. **Update or create docs**
   - Prefer updating existing files
   - Create new only if distinct topic

## Content Rules

### DO Include

- Package structure with file tree diagrams
- Export organization (what exports from where)
- Files changed with their purpose (use tables)
- Feature flags used (with code example)
- Key patterns followed (with code examples)
- Decisions made and WHY (rationale is crucial)
- Deprecated APIs discovered → add to deprecated-apis.md
- Mock data status (if applicable)
- Status: POC | Feature-flagged | Production-ready
- Caveats and gotchas
- **ESLint rules and restrictions** that affect implementation (with file location)
- **Existing components to reuse** instead of creating new ones
- **Type export patterns** (export derived types from repositories, not inline)

### DO NOT Include

- Implementation details obvious from code
- Redundant explanations
- Time estimates or schedules
- Personal notes or TODOs
- Information already in another doc file

## Key Patterns to Document

When you discover or establish these, add to `.claude/patterns/`:

| Pattern | File |
|---------|------|
| Code quality verification | `code-quality-verification.md` |
| Deprecated APIs | `deprecated-apis.md` |
| Package export organization | `package-export-organization.md` |
| Server-side data fetching | `server-side-data-fetching.md` |
| Tailwind theme tokens | `tailwind-theme-tokens.md` |

## Capturing Conversation Learnings

**IMPORTANT**: When the user asks to "update docs with what you've learned", review the entire conversation for:

1. **Corrections the user made** - If they said "don't do X" or "we should use Y instead"
2. **Patterns they insinuated** - File organization preferences, naming conventions
3. **ESLint/linting rules encountered** - Rules that blocked or changed implementation
4. **Existing components pointed out** - "We already have this" or "use the existing X"
5. **Type organization preferences** - Where types should be defined and exported
6. **Questions they asked** - Often reveal expectations (e.g., "don't we already have this type?")

Document these as concrete patterns with examples, not vague guidelines.

## Cleanup Checklist

Run this EVERY time:

- [ ] Scan `.claude/plans/` - delete completed plans
- [ ] Scan `.claude/context/` - remove outdated feature docs
- [ ] Scan `.claude/patterns/` - update stale code examples
- [ ] Check `CLAUDE.md` - remove feature-specific details (belongs in context/)
- [ ] Search for conflicts - same info in multiple places
- [ ] Search for redundancy - consolidate duplicates

## Update Checklist

- [ ] Identify changed files
- [ ] Update or create context doc in `.claude/context/`
- [ ] Extract reusable patterns to `.claude/patterns/`
- [ ] Document any deprecated APIs found
- [ ] Record architectural decisions with rationale
- [ ] Use tables for file lists
- [ ] Include code examples for patterns
- [ ] Delete completed plans from `.claude/plans/`

## Template: Feature Context

```markdown
# Feature Name

Brief description.

## Status

POC | Feature-flagged | Production-ready

## Package Structure

\`\`\`text
packages/domain/{feature}/src/
├── components/
│   └── index.ts
├── hooks/
│   └── index.ts
└── repositories/
    └── index.ts
\`\`\`

## Export Organization

| Type | Import From |
|------|-------------|
| Components | `@optimus/pkg/src/components` |
| Hooks | `@optimus/pkg/src/hooks` |
| Types | `@optimus/pkg/src/repositories` |

## Files

| Package | File | Purpose |
|---------|------|---------|
| `@optimus/pkg` | `src/file.ts` | Description |

## Feature Flag (if applicable)

\`\`\`typescript
const isEnabled = isFeatureFlagActive(FLAG_NAME);
\`\`\`

## Key Patterns

- Pattern 1 (see `.claude/patterns/pattern-name.md`)
- Pattern 2

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Keep duplication in X vs Y | Different evolution paths expected |
| Use hook A instead of B | B is deprecated |

## Caveats

- Caveat 1
- Caveat 2
```

## Template: Pattern

```markdown
# Pattern Name

## When to Use

Description of when this pattern applies.

## Implementation

\`\`\`typescript
// Code example from codebase
\`\`\`

## Key Principles

1. Principle 1
2. Principle 2

## Examples in Codebase

- `packages/domain/example/src/file.ts`
```

## Template: Architectural Decision

```markdown
## Decision: [Title]

**Date**: YYYY-MM-DD
**Status**: Accepted | Superseded | Deprecated

### Context

What is the issue we're addressing?

### Decision

What did we decide?

### Rationale

Why did we choose this approach?

### Consequences

What are the implications?

### Alternatives Considered

What other options were evaluated?
```
