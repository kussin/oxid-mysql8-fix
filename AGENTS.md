# AGENTS.md

This file defines repository-specific instructions for AI/code agents working in `oxid-mysql8-fix`.

## Scope

This repository provides a public OXID eShop 6.5.x MySQL 8 workaround package.

- `copy_this/`: files intended to be copied into an OXID Composer root via FTP/SFTP or deployment.
- `README.md`: public usage documentation.
- `CHANGELOG.md`: release history.
- `version.txt`: leading version source for this repository.
- `LICENSE.md`: license terms.

## Mandatory Rules

1. All documentation must be written in English.
   - This includes Markdown files, release notes, comments intended for users, and examples.
   - German may be used in conversations, but not in repository documentation.

2. Treat `version.txt` as the leading version source.
   - If the package version changes, update `version.txt`.
   - Keep `README.md` and `CHANGELOG.md` aligned with the version where relevant.

3. Do not commit project-specific secrets or database exports.
   - Never add `*.sql`, `*.log`, `config.inc.php`, credentials, license keys, API keys, or customer-specific dumps.
   - Keep the repository generic and safe for public distribution.

4. Keep `copy_this/` ready for direct FTP/SFTP upload.
   - Files in `copy_this/` must be usable from the OXID Composer root after copying.
   - Do not introduce paths that only work in the original customer project.

5. Keep the workaround narrow.
   - This repository targets the OXID 6.5.x `ENCODE()` / `DECODE()` problem around `oxconfig`.
   - Avoid unrelated OXID upgrades, broad refactors, or customer-specific deployment logic.

## Verification Checklist

Before finishing a change:

1. Confirm `copy_this/` contains only files intended for public use.
2. Confirm no SQL dumps, logs, credentials, or environment-specific files were added.
3. Confirm Markdown documentation is in English.
4. Confirm `version.txt`, `README.md`, and `CHANGELOG.md` are consistent.
5. If files were copied from another project, confirm the copied files match the intended source state.
