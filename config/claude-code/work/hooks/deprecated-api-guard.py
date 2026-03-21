#!/usr/bin/env python3
"""
Deprecated API Guard Hook - PreToolUse (Edit|Write)

Blocks usage of deprecated APIs in new code.
Provides replacement suggestions.

This hook is OLX-specific and checks for deprecated OLX APIs.

Exit codes:
  0 - No deprecated APIs found
  2 - Deprecated API found (blocks the action)
"""

import json
import sys
import re

# Deprecated APIs with their replacements
DEPRECATED_APIS = {
    # useBreakpoints deprecation
    "useBreakpoints": {
        "pattern": r"useBreakpoints",
        "replacement": "useUIConfig from @optimus/custom-components",
        "example": """
// Instead of:
import { useBreakpoints } from "@optimus/theme/src/hooks/use-breakpoints";
const { isMobile } = useBreakpoints();

// Use:
import { useUIConfig } from "@optimus/custom-components";
const { type } = useUIConfig();
const isMobile = type === "mobile";
"""
    },
    # Direct import from theme hooks
    "@optimus/theme/src/hooks/use-breakpoints": {
        "pattern": r"@optimus/theme/src/hooks/use-breakpoints",
        "replacement": "@optimus/custom-components",
        "example": "Import useUIConfig from @optimus/custom-components instead"
    },
}

def check_for_deprecated_apis(content: str) -> list:
    """Check content for deprecated API usage."""
    issues = []

    for api_name, info in DEPRECATED_APIS.items():
        if re.search(info["pattern"], content):
            issues.append({
                "api": api_name,
                "replacement": info["replacement"],
                "example": info.get("example", "")
            })

    return issues

def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})

    # Get the content being written/edited
    content_to_check = ""

    if tool_name == "Write":
        content_to_check = tool_input.get("content", "")
    elif tool_name == "Edit":
        content_to_check = tool_input.get("new_string", "")

    if not content_to_check:
        sys.exit(0)

    issues = check_for_deprecated_apis(content_to_check)

    if issues:
        messages = []
        for issue in issues:
            messages.append(f"DEPRECATED API: {issue['api']}")
            messages.append(f"Use instead: {issue['replacement']}")
            if issue['example']:
                messages.append(f"Example:{issue['example']}")
            messages.append("")

        error_message = "\n".join([
            "BLOCKED: Deprecated API detected",
            "",
            *messages,
            "See .claude/patterns/deprecated-apis.md for more details."
        ])

        print(error_message, file=sys.stderr)
        sys.exit(2)

    sys.exit(0)

if __name__ == "__main__":
    main()
