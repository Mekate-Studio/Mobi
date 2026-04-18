# Security Policy

`Mobi` is a public reference architecture repository. If you believe you have
found a real security vulnerability in the code, examples, or documented
patterns here, please report it responsibly.

## Reporting A Vulnerability

- Do not open a public issue with exploit details, secrets, or a full
  reproduction for a sensitive vulnerability.
- Prefer GitHub's private vulnerability reporting features if they are enabled
  for this repository.
- If private vulnerability reporting is not available yet, do not disclose the
  details publicly. Wait for maintainers to publish a dedicated private
  reporting path.

## What To Report

Useful reports usually involve one or more of these:

- a vulnerability in committed code
- an insecure default or example that could realistically mislead adopters
- exposed credentials, tokens, keys, or other sensitive material in the repo
- documentation that recommends a materially unsafe practice

Lower-priority reports usually include:

- purely theoretical concerns with no realistic exploit path
- general architecture disagreements framed as security issues
- vulnerabilities that exist only in a consumer's unrelated downstream changes

## What To Include

When reporting a vulnerability, include:

- the affected file, component, or documented pattern
- the impact you believe it has
- the conditions required to exploit it
- a minimal reproduction or proof of concept when safe to share privately
- any suggested mitigation if you already have one

## Expectations

- Maintainers may need time to validate whether the report applies to this
  repository or only to a downstream implementation.
- Because `Mobi` is a reference architecture repository, some findings may lead
  to documentation changes, example hardening, or explicit warnings rather than
  a traditional product-style patch release.
- A more formal private reporting path should be added as the public repo
  matures.
