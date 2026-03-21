#!/usr/bin/env node

/**
 * Security Check Hook
 *
 * Runs before file edits to detect potential security issues.
 * Checks for:
 * - Hardcoded secrets (API keys, passwords, tokens)
 * - Dangerous patterns (eval, innerHTML)
 * - Sensitive file modifications
 *
 * Usage: Called by Claude Code PreToolUse hook
 * Exit codes:
 *   0 - No issues found
 *   1 - Warning (continues with message)
 *   2 - Error (blocks action)
 */

const fs = require('fs');
const path = require('path');

// Patterns that indicate potential secrets
const SECRET_PATTERNS = [
  // API Keys
  /['"](?:api[_-]?key|apikey)['"]:\s*['"][a-zA-Z0-9]{20,}['"]/gi,
  /(?:api[_-]?key|apikey)\s*=\s*['"][a-zA-Z0-9]{20,}['"]/gi,

  // AWS
  /AKIA[0-9A-Z]{16}/g,
  /(?:aws[_-]?secret|secret[_-]?key)\s*=\s*['"][a-zA-Z0-9/+=]{40}['"]/gi,

  // Private keys
  /-----BEGIN (?:RSA |EC |DSA )?PRIVATE KEY-----/g,

  // Passwords
  /['"](?:password|passwd|pwd)['"]:\s*['"][^'"]{8,}['"]/gi,
  /(?:password|passwd|pwd)\s*=\s*['"][^'"]{8,}['"]/gi,

  // Tokens
  /(?:bearer|token|auth)\s*[:=]\s*['"][a-zA-Z0-9._-]{20,}['"]/gi,

  // Connection strings with credentials
  /(?:mongodb|postgres|mysql|redis):\/\/[^:]+:[^@]+@/gi,
];

// Dangerous code patterns
const DANGEROUS_PATTERNS = [
  { pattern: /eval\s*\(/g, message: 'eval() usage detected - potential code injection' },
  { pattern: /innerHTML\s*=/g, message: 'innerHTML assignment - potential XSS vulnerability' },
  { pattern: /dangerouslySetInnerHTML/g, message: 'dangerouslySetInnerHTML - ensure content is sanitized' },
  { pattern: /document\.write\s*\(/g, message: 'document.write() - avoid in modern code' },
  { pattern: /exec\s*\(\s*['"`]/g, message: 'exec() with string - potential command injection' },
  { pattern: /child_process.*exec/g, message: 'child_process exec - verify input sanitization' },
];

// Sensitive file paths
const SENSITIVE_PATHS = [
  '.env',
  '.env.local',
  '.env.production',
  'credentials',
  'secrets',
  '.pem',
  '.key',
  'id_rsa',
  'id_ed25519',
];

function checkForSecrets(content) {
  const issues = [];

  for (const pattern of SECRET_PATTERNS) {
    const matches = content.match(pattern);
    if (matches) {
      issues.push({
        type: 'secret',
        severity: 'error',
        message: `Potential secret detected: ${matches[0].substring(0, 30)}...`,
      });
    }
  }

  return issues;
}

function checkForDangerousPatterns(content) {
  const issues = [];

  for (const { pattern, message } of DANGEROUS_PATTERNS) {
    if (pattern.test(content)) {
      issues.push({
        type: 'dangerous',
        severity: 'warning',
        message,
      });
    }
  }

  return issues;
}

function isSensitivePath(filePath) {
  const normalizedPath = filePath.toLowerCase();
  return SENSITIVE_PATHS.some(sensitive =>
    normalizedPath.includes(sensitive)
  );
}

function main() {
  // Get file path from environment or arguments
  const filePath = process.env.CLAUDE_FILE_PATH || process.argv[2];

  if (!filePath) {
    // No file specified, nothing to check
    process.exit(0);
  }

  // Check if modifying sensitive file
  if (isSensitivePath(filePath)) {
    console.log(`⚠️  WARNING: Modifying sensitive file: ${filePath}`);
    console.log('   Ensure no secrets are being committed.');
  }

  // If file exists, check its content
  if (fs.existsSync(filePath)) {
    try {
      const content = fs.readFileSync(filePath, 'utf8');
      const secretIssues = checkForSecrets(content);
      const dangerousIssues = checkForDangerousPatterns(content);

      const allIssues = [...secretIssues, ...dangerousIssues];

      if (allIssues.length > 0) {
        console.log('\n🔒 Security Check Results:');
        console.log('─'.repeat(40));

        for (const issue of allIssues) {
          const icon = issue.severity === 'error' ? '🚨' : '⚠️';
          console.log(`${icon} ${issue.message}`);
        }

        console.log('─'.repeat(40));

        // Exit with error only if secrets detected
        const hasErrors = allIssues.some(i => i.severity === 'error');
        if (hasErrors) {
          console.log('\n❌ BLOCKED: Potential secrets detected. Please review.');
          process.exit(2);
        }
      }
    } catch (err) {
      // File might be binary or unreadable, skip
    }
  }

  process.exit(0);
}

main();
