# KUSSIN | MySQL 8.0 Fix for OXID eShop 6 

Pragmatic workaround for OXID eShop 6.5.x installations that fail on MySQL 8 because the MySQL functions `ENCODE()` and `DECODE()` are no longer available.

The typical error looks like this:

```text
SQLSTATE[42000]: Syntax error or access violation: 1305 FUNCTION ... DECODE does not exist
```

## Background

OXID eShop 6.5.x still uses MySQL `ENCODE()` and `DECODE()` in several places for values stored in `oxconfig` and some legacy payment value lookups. MySQL 8 no longer provides these functions. When a hosting provider migrates an existing MySQL 5.7 database to MySQL 8, shop configuration values and affected checkout paths can no longer be read or written correctly.

PROFIHOST documents the planned MySQL 5.7 to MySQL 8.0 upgrades in its help center and recommends checking applications for MySQL 8 compatibility in time:

https://help.profihost.com/hc/de/articles/38643449927697-Wann-wird-das-MySQL-8-Update-auf-unseren-Servern-stattfinden

## Important Disclaimer

This repository is provided free of charge and without any warranty.

Use it entirely at your own risk. No liability is accepted for data loss, downtime, broken configuration, security issues, or any other direct or indirect damage.

Before using this workaround, you must create a complete database backup and ideally a server or filesystem snapshot. Test the process on DEV or STAGING first. Do not run it untested on PROD.

## Contents

The files in [`copy_this/`](copy_this/) are intended to be copied via FTP/SFTP or deployment into the OXID Composer root, meaning the directory that contains `composer.json` and `vendor/`.

```text
copy_this/
  mysql8-config-encode-decode.patch
  oxconfig-mysql8-transition.sh
```

After copying, the OXID project should look like this:

```text
oxid-project/
  composer.json
  vendor/
  source/
  mysql8-config-encode-decode.patch
  oxconfig-mysql8-transition.sh
```

## Process Overview

The safest process has two phases:

1. Before the MySQL 8 migration, create a decoded copy of the `oxconfig` table on a still-compatible MySQL 5.7 or MariaDB instance.
2. After installing the patch, replace the original `oxconfig` table with the decoded copy.

If your database has already been migrated to MySQL 8 and no old dump or compatible database instance is available, existing `ENCODE()` values can no longer be decoded cleanly. In that case, affected configuration values must be repaired or written again manually.

## Installation via FTP/SFTP

Copy all files from `copy_this/` into the OXID Composer root:

```text
oxid-project/
  composer.json
  vendor/
  source/
  mysql8-config-encode-decode.patch
  oxconfig-mysql8-transition.sh
```

Make the script executable on the server:

```bash
chmod +x oxconfig-mysql8-transition.sh
```

## Step 1: Create a Decoded oxconfig Copy

This step must run before the MySQL 8 migration, while `ENCODE()` and `DECODE()` still work on the database server.

```bash
cd /path/to/oxid-project
./oxconfig-mysql8-transition.sh create-copy oxconfig_decoded_mysql8
./oxconfig-mysql8-transition.sh verify oxconfig_decoded_mysql8
./oxconfig-mysql8-transition.sh dump oxconfig_decoded_mysql8 oxconfig_decoded_mysql8.sql
```

The script reads the database credentials from `source/config.inc.php`. If your config file is in a different location:

```bash
CONFIG_FILE=/path/to/config.inc.php ./oxconfig-mysql8-transition.sh create-copy oxconfig_decoded_mysql8
```

## Step 2: Apply the Patch

Option A: apply manually with `patch`:

```bash
cd /path/to/oxid-project
patch -d vendor/oxid-esales/oxideshop-ce -p1 < mysql8-config-encode-decode.patch
```

Option B: apply through `cweagans/composer-patches` in `composer.json`:

```json
{
  "extra": {
    "patches": {
      "oxid-esales/oxideshop-ce": {
        "MySQL 8 config ENCODE/DECODE workaround": "mysql8-config-encode-decode.patch"
      }
    }
  }
}
```

Then run Composer according to your project setup, for example:

```bash
composer install
```

## Step 3: Swap the oxconfig Table

Only run this after the patch has been installed successfully:

```bash
cd /path/to/oxid-project
CONFIRM_SWAP=1 ./oxconfig-mysql8-transition.sh swap oxconfig_decoded_mysql8
rm -rf source/tmp/*
vendor/bin/oe-console oe:module:apply-configuration
```

The script keeps the old table by renaming it:

```text
oxconfig -> oxconfig_encoded_backup_<timestamp>
oxconfig_decoded_mysql8 -> oxconfig
```

## Rollback

If problems occur immediately after the swap, rename the backup table back. Example:

```sql
RENAME TABLE
  oxconfig TO oxconfig_failed_mysql8_swap,
  oxconfig_encoded_backup_YYYYMMDDHHMMSS TO oxconfig;
```

Then clear the OXID cache:

```bash
rm -rf source/tmp/*
```

## Known Limitations

- This patch is a workaround for OXID eShop 6.5.x, not official MySQL 8 support.
- Existing encrypted `oxconfig` values must be decoded before the MySQL 8 migration.
- After applying the patch, affected `oxconfig` values are stored unencrypted.
- The patch contains a narrow fallback for legacy code that still queries already-decoded `oxconfig` values through `DECODE(oxvarvalue, '...')` or `DECODE(cfg.oxvarvalue, '...')`.
- The patch also normalizes legacy `oxuserpayments.oxvalue` reads such as `DECODE(oxvalue, '...')`, which can be triggered during order finalization.
- Additional MySQL 8 incompatibilities may still exist in project code or third-party modules.
- The patch was derived from a real migration case and must always be tested for the specific project.

## Versioning

The current release version is stored in [`version.txt`](version.txt). Treat this file as the leading version source for this repository.

## License

MIT License. See [`LICENSE.md`](LICENSE.md).

---

&copy; 2006-2026 [Kussin | eCommerce und Online-Marketing GmbH](https://www.kussin.de/). All rights reserved.
