#!/usr/bin/env node

/**
 * Dedicated Tool Enforcer Hook
 *
 * Blocks Bash commands that should use dedicated Claude Code tools instead.
 * Prevents cat/head/tail (use Read), grep/rg (use Grep), find (use Glob),
 * sed/awk (use Edit).
 *
 * Usage: Called by Claude Code PreToolUse hook on Bash
 * Exit codes:
 *   0 - Command is fine
 *   2 - Blocked (must use dedicated tool)
 */

const REDIRECTS = [
  {
    pattern: /^cat\s/,
    tool: 'Read',
    message: 'Use the Read tool to read file contents',
  },
  {
    pattern: /^head\s/,
    tool: 'Read (with limit parameter)',
    message: 'Use the Read tool with offset/limit to read partial files',
  },
  {
    pattern: /^tail\s/,
    tool: 'Read (with offset parameter)',
    message: 'Use the Read tool with offset to read from a specific line',
  },
  {
    pattern: /^sed\s/,
    tool: 'Edit',
    message: 'Use the Edit tool for find-and-replace operations',
  },
  {
    pattern: /^awk\s/,
    tool: 'Edit',
    message: 'Use the Edit tool or Read + processing instead of awk',
  },
  {
    pattern: /^(grep|rg|egrep|fgrep)\s/,
    tool: 'Grep',
    message: 'Use the Grep tool for content search',
  },
  {
    pattern: /^find\s/,
    tool: 'Glob',
    message: 'Use the Glob tool for file pattern matching',
  },
];

function main() {
  let input = '';

  process.stdin.setEncoding('utf8');
  process.stdin.on('data', (chunk) => {
    input += chunk;
  });

  process.stdin.on('end', () => {
    try {
      const data = JSON.parse(input);
      const command = (data.command || '').trim();

      for (const { pattern, tool, message } of REDIRECTS) {
        if (pattern.test(command)) {
          console.log(`\nBLOCKED: ${message}`);
          console.log(`  Tool: ${tool}`);
          console.log(`  Attempted: ${command.substring(0, 80)}${command.length > 80 ? '...' : ''}`);
          console.log('');
          process.exit(2);
        }
      }
    } catch {
      // If we can't parse input, let it through
    }

    process.exit(0);
  });
}

main();
