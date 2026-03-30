#!/usr/bin/env node

/**
 * Console Log Detector Hook
 *
 * Warns when console.log statements are added to production code.
 * Helps maintain clean code by detecting debugging statements.
 *
 * Usage: Called by Claude Code PreToolUse hook
 * Exit codes:
 *   0 - No issues or file is test/debug
 *   1 - Warning (console.log detected, continues)
 */

const fs = require('fs');
const path = require('path');

// Files where console.log is acceptable
const ALLOWED_PATTERNS = [
  /\.test\.[jt]sx?$/,           // Test files
  /\.spec\.[jt]sx?$/,           // Spec files
  /__tests__\//,                 // Test directories
  /\.stories\.[jt]sx?$/,         // Storybook
  /scripts\//,                   // Build scripts
  /tools\//,                     // Tool scripts
  /debug/i,                      // Debug files
  /logger/i,                     // Logger implementations
  /console-log-detector\.js$/,   // This file
];

// Console methods to detect
const CONSOLE_METHODS = [
  'console.log',
  'console.debug',
  'console.info',
  'console.warn',
  'console.error',
  'console.trace',
  'console.dir',
  'console.table',
];

function isAllowedFile(filePath) {
  return ALLOWED_PATTERNS.some(pattern => pattern.test(filePath));
}

function detectConsoleLogs(content) {
  const issues = [];
  const lines = content.split('\n');

  lines.forEach((line, index) => {
    // Skip commented lines
    if (line.trim().startsWith('//') || line.trim().startsWith('*')) {
      return;
    }

    for (const method of CONSOLE_METHODS) {
      if (line.includes(method)) {
        issues.push({
          line: index + 1,
          method,
          content: line.trim().substring(0, 60),
        });
      }
    }
  });

  return issues;
}

function main() {
  const filePath = process.env.CLAUDE_FILE_PATH || process.argv[2];

  if (!filePath) {
    process.exit(0);
  }

  // Skip allowed files
  if (isAllowedFile(filePath)) {
    process.exit(0);
  }

  // Only check JavaScript/TypeScript files
  if (!/\.[jt]sx?$/.test(filePath)) {
    process.exit(0);
  }

  if (!fs.existsSync(filePath)) {
    process.exit(0);
  }

  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const issues = detectConsoleLogs(content);

    if (issues.length > 0) {
      console.log('\n📝 Console Statement Detection:');
      console.log('─'.repeat(50));
      console.log(`File: ${filePath}`);
      console.log('');

      for (const issue of issues) {
        console.log(`  Line ${issue.line}: ${issue.method}`);
        console.log(`    ${issue.content}...`);
      }

      console.log('');
      console.log('─'.repeat(50));
      console.log('⚠️  REMINDER: Remove console statements before completion.');
      console.log('   Debug code should not be committed to production.');
      console.log('');

      // Don't block, just warn
      process.exit(0);
    }
  } catch (err) {
    // File might be unreadable, skip
  }

  process.exit(0);
}

main();
