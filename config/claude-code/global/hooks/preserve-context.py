#!/usr/bin/env python3
"""
PreCompact Hook - Preserve Critical Context

Runs before context window compression to re-inject essential state
that should survive compaction.

Reads active context files and outputs them as additional context
so they're included in the compressed summary.

Exit codes:
  0 - Success
"""

import json
import sys
import os
from pathlib import Path


def find_active_context(project_dir: str) -> list:
    """Find active context files in .claude/context/."""
    context_dir = Path(project_dir) / ".claude" / "context"
    contexts = []

    if context_dir.exists():
        for f in sorted(context_dir.glob("*.md")):
            try:
                content = f.read_text().strip()
                if content:
                    contexts.append({
                        "name": f.stem,
                        "content": content[:2000]
                    })
            except Exception:
                pass

    return contexts


def find_active_plans(project_dir: str) -> list:
    """Find in-progress plan files."""
    plans_dir = Path(project_dir) / ".claude" / "plans"
    plans = []

    if plans_dir.exists():
        for f in sorted(plans_dir.glob("*.md")):
            try:
                content = f.read_text()
                if "## Status" in content and "in_progress" in content.lower():
                    plans.append(f.stem)
            except Exception:
                pass

    return plans


def main():
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", ".")

    context_items = find_active_context(project_dir)
    active_plans = find_active_plans(project_dir)

    if not context_items and not active_plans:
        sys.exit(0)

    lines = ["PRESERVED CONTEXT (from PreCompact hook)", ""]

    if active_plans:
        lines.append("Active plans: " + ", ".join(active_plans))
        lines.append("")

    for ctx in context_items[:3]:
        lines.append(f"--- {ctx['name']} ---")
        lines.append(ctx["content"])
        lines.append("")

    output = {
        "hookSpecificOutput": {
            "hookEventName": "PreCompact",
            "additionalContext": "\n".join(lines)
        }
    }
    print(json.dumps(output))
    sys.exit(0)


if __name__ == "__main__":
    main()
