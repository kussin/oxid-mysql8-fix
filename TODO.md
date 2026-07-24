# TODO

This checklist collects MySQL 8 compatibility topics that are relevant for OXID eShop 6.x projects in general. It intentionally avoids customer-specific module names, credentials, logs, and database exports.

## OXID 6 Core Areas

- [ ] Test OXID admin configuration screens that read or write `oxconfig`.
- [ ] Test theme settings for active and inactive themes.
- [ ] Test module settings for enabled and disabled modules.
- [ ] Test `vendor/bin/oe-console oe:module:apply-configuration`.
- [ ] Test cache clearing and warmup after patch installation.
- [ ] Test shop startup for all configured subshops or editions.
- [ ] Test checkout with standard OXID payment methods that load `oxuserpayments.oxvalue`.
- [ ] Check logs for remaining `ENCODE()` or `DECODE()` SQL errors.

## oxconfig Transition

- [ ] Create a decoded `oxconfig` copy before switching to MySQL 8.
- [ ] Verify decoded table row counts against the original `oxconfig`.
- [ ] Verify representative array, boolean, string, and select settings.
- [ ] Export the decoded table before swapping.
- [ ] Swap the decoded table only after the patch has been installed.
- [ ] Keep the old encoded `oxconfig` table as rollback backup.
- [ ] Confirm newly saved settings are written without MySQL `ENCODE()`.

## Third-Party Module Risks

- [ ] Check modules that read `oxconfig` directly instead of using OXID config APIs.
- [ ] Check modules that still execute `DECODE(oxvarvalue, '...')`.
- [ ] Check modules that still execute `ENCODE(..., '...')` on writes.
- [ ] Check ionCube-protected modules separately, because direct source patches may not be possible.
- [ ] Test payment modules in backend configuration and checkout.
- [ ] Test marketplace, ERP, and feed modules through their CLI jobs and backend screens.
- [ ] Test analytics, consent, captcha, and tracking modules in frontend and backend.

## SQL Mode Compatibility

- [ ] Check for inserts or updates using `0000-00-00` or `0000-00-00 00:00:00`.
- [ ] Check custom SQL queries against `ONLY_FULL_GROUP_BY`.
- [ ] Check arithmetic queries for division-by-zero behavior.
- [ ] Check code that depends on silent truncation or implicit invalid-date conversion.
- [ ] Confirm the effective `@@GLOBAL.sql_mode` and `@@SESSION.sql_mode` on the target server.

## Charset and Collation

- [ ] Check database, table, and column charsets for mixed `latin1`, `utf8`, `utf8mb3`, and `utf8mb4` usage.
- [ ] Check joins and comparisons across columns with different collations.
- [ ] Check imports and dumps for explicit `utf8` usage.
- [ ] Prefer explicit `utf8mb4` for new project-specific tables where compatible with the existing schema.

## Reserved Words and SQL Syntax

- [ ] Check custom table and column names against MySQL 8 reserved words.
- [ ] Quote identifiers with backticks where unavoidable.
- [ ] Check custom SQL containing `GROUPS`, `RANK`, `WINDOW`, `SYSTEM`, `RECURSIVE`, or `LATERAL`.

## Client and Hosting Compatibility

- [ ] Confirm PHP can connect to MySQL 8 with the configured authentication plugin.
- [ ] Confirm CLI tools can connect with the same credentials as the web runtime.
- [ ] Confirm deployment scripts, backup scripts, and admin SQL tools still connect.
- [ ] Confirm TLS/authentication settings do not break older tooling.

## Performance Regression Checks

- [ ] Test category listings, search, product detail pages, basket, and checkout.
- [ ] Test export and feed generation jobs.
- [ ] Test backend article, category, order, and user lists.
- [ ] Review slow query logs after the MySQL 8 switch.
- [ ] Compare critical query plans where runtime changed significantly.
