#!/usr/bin/env python3
"""
Cleanup Reminder Hook - Stop

Scans recently modified files for leftover debug code.
Warns about console.log, debugger statements, etc.

Exit codes:
  0 - Success (with warnings if issues found)
"""

import json
import sys
import os
import re
import subprocess
from pathlib import Path
from datetime import datetime, timedelta

# Patterns to check for
DEBUG_PATTERNS = [
    (r'\bconsole\.log\b', "console.log statement"),
    (r'\bconsole\.debug\b', "console.debug statement"),
    (r'\bdebugger\b', "debugger statement"),
    (r'// TODO:', "TODO comment"),
    (r'// FIXME:', "FIXME comment"),
    (r'// HACK:', "HACK comment"),
]

# Files to skip
SKIP_PATTERNS = [
    r'\.test\.',
    r'\.spec\.',
    r'\.stories\.',
    r'__tests__',
    r'__mocks__',
    r'node_modules',
    r'\.claude/',
    r'scripts/',
]

def should_skip_file(file_path: str) -> bool:
    """Check if file should be skipped."""
    for pattern in SKIP_PATTERNS:
        if re.search(pattern, file_path):
            return True
    return False

def get_recently_modified_files(project_dir: str) -> list:
    """Get TypeScript files modified in the last hour."""
    try:
        result = subprocess.run(
            ['find', project_dir, '-type', 'f', '-name', '*.ts', '-o', '-name', '*.tsx',
             '-mmin', '-60'],
            capture_output=True,
            text=True,
            timeout=10
        )
        files = [f for f in result.stdout.strip().split('\n') if f and not should_skip_file(f)]
        return files[:20]  # Limit to 20 files
    except Exception:
        return []

def check_file_for_debug_code(file_path: str) -> list:
    """Check a file for debug code patterns."""
    issues = []
    try:
        with open(file_path, 'r') as f:
            content = f.read()
            lines = content.split('\n')

        for i, line in enumerate(lines, 1):
            # Skip commented lines for some checks
            if line.strip().startswith('//'):
                continue

            for pattern, description in DEBUG_PATTERNS:
                if re.search(pattern, line):
                    issues.append({
                        "file": file_path,
                        "line": i,
                        "type": description,
                        "content": line.strip()[:50]
                    })
    except Exception:
        pass

    return issues

def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        input_data = {}

    # Don't run if stop hook is already active (prevent infinite loops)
    if input_data.get("stop_hook_active", False):
        sys.exit(0)

    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", input_data.get("cwd", "."))

    # Get recently modified files
    files = get_recently_modified_files(project_dir)

    if not files:
        sys.exit(0)

    # Check all files
    all_issues = []
    for file_path in files:
        issues = check_file_for_debug_code(file_path)
        all_issues.extend(issues)

    if all_issues:
        # Group by file
        by_file = {}
        for issue in all_issues:
            file_path = issue["file"]
            if file_path not in by_file:
                by_file[file_path] = []
            by_file[file_path].append(issue)

        # Build warning message
        warning_lines = ["CLEANUP REMINDER", "Debug code found in recently modified files:", ""]

        for file_path, issues in list(by_file.items())[:5]:  # Limit to 5 files
            rel_path = os.path.relpath(file_path, project_dir)
            warning_lines.append(f"  {rel_path}:")
            for issue in issues[:3]:  # Limit to 3 issues per file
                warning_lines.append(f"    Line {issue['line']}: {issue['type']}")

        warning_lines.extend([
            "",
            "Please clean up debug code before completing.",
            ""
        ])

        # Output warning (doesn't block, just warns)
        print("\n".join(warning_lines))

    sys.exit(0)

if __name__ == "__main__":
    main()
