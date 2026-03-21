#!/usr/bin/env python3
"""
MCP Tool Suggester Hook - PreToolUse (Bash)

Suggests better MCP tools when Bash commands could use dedicated tools.
Does not block, just adds suggestions.

Exit codes:
  0 - Success (with suggestions if applicable)
"""

import json
import sys
import re

# Bash command patterns -> MCP tool suggestions
TOOL_SUGGESTIONS = {
    # File reading
    r"\bcat\s+": {
        "tool": "Read",
        "message": "Use the Read tool instead of 'cat' for better file handling"
    },
    r"\bhead\s+": {
        "tool": "Read (with limit parameter)",
        "message": "Use Read tool with limit parameter instead of 'head'"
    },
    r"\btail\s+": {
        "tool": "Read (with offset parameter)",
        "message": "Use Read tool with offset parameter instead of 'tail'"
    },

    # File searching
    r"\bgrep\s+": {
        "tool": "Grep",
        "message": "Use the Grep tool for content search with better output formatting"
    },
    r"\brg\s+": {
        "tool": "Grep",
        "message": "Use the Grep tool instead of ripgrep for consistent results"
    },
    r"\bfind\s+.*-name": {
        "tool": "Glob",
        "message": "Use the Glob tool for file pattern matching"
    },

    # Browser automation
    r"\bcurl\s+.*localhost": {
        "tool": "mcp__playwright__browser_navigate",
        "message": "For UI testing, consider using Playwright MCP tools"
    },
}

def find_tool_suggestions(command: str) -> list:
    """Find applicable tool suggestions for the command."""
    suggestions = []

    for pattern, info in TOOL_SUGGESTIONS.items():
        if re.search(pattern, command):
            suggestions.append(info)

    return suggestions

def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    tool_name = input_data.get("tool_name", "")
    if tool_name != "Bash":
        sys.exit(0)

    tool_input = input_data.get("tool_input", {})
    command = tool_input.get("command", "")

    if not command:
        sys.exit(0)

    suggestions = find_tool_suggestions(command)

    if suggestions:
        # Don't block, just provide JSON output with suggestions
        suggestion_lines = []
        for s in suggestions[:2]:  # Limit to 2 suggestions
            suggestion_lines.append(f"  - {s['tool']}: {s['message']}")

        output = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "additionalContext": "\n".join([
                    "TOOL SUGGESTION",
                    "Consider using dedicated tools for better results:",
                    *suggestion_lines
                ])
            }
        }
        print(json.dumps(output))

    sys.exit(0)

if __name__ == "__main__":
    main()
