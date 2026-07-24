# Changelog

## 0.1.2

- Extended the legacy `DECODE()` fallback to also handle aliased `oxconfig` queries such as `DECODE(cfg.oxvarvalue, '...')`.
- Covers OXID admin theme configuration screens that load theme settings through `ShopConfiguration::loadConfVars()`.

## 0.1.1

- Added a narrow database adapter fallback for legacy modules that still run `SELECT DECODE(oxvarvalue, '...') ... FROM oxconfig` after the decoded `oxconfig` transition.
- Keeps compatibility with ionCube-protected third-party modules where the original SQL cannot be patched directly.

## 0.1.0

- Added OXID eShop 6.5.x MySQL 8 workaround patch for `ENCODE()` / `DECODE()` usage in `oxconfig`.
- Added transition script to create, verify, dump, and swap a decoded `oxconfig` table copy.
- Added usage documentation and explicit backup / no-liability warnings.
