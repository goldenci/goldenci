# Security Policy

## Supported Versions

Only the latest major version (currently `v1`) receives security fixes.

## Reporting a Vulnerability

Please do **not** open a public issue for security vulnerabilities.

Instead, use [GitHub's private vulnerability reporting](https://github.com/goldenci/goldenci/security/advisories/new) for this repository. Include:

- A description of the vulnerability and its impact
- Steps to reproduce (a minimal workflow that uses the action is ideal)
- Any known mitigations

You should expect an initial response within 5 business days.

## Scope

GoldenCI is a composite GitHub Action / reusable workflow. Security-relevant reports include (but aren't limited to):

- Ways the action could execute untrusted code beyond what the calling repository already runs
- Supply-chain issues in a pinned dependency (e.g. a compromised action SHA)
- Privilege escalation via workflow inputs or outputs
