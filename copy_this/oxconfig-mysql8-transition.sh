#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
TABLE_NAME="${2:-}"
OUTPUT_FILE="${3:-}"

CONFIG_FILE="${CONFIG_FILE:-source/config.inc.php}"
MYSQL_BIN="${MYSQL_BIN:-mysql}"
MYSQLDUMP_BIN="${MYSQLDUMP_BIN:-mysqldump}"
DEFAULT_CONFIG_KEY="fq45QS09_fqyx09239QQ"

usage() {
    cat <<'USAGE'
Usage:
  ./oxconfig-mysql8-transition.sh create-copy [copy_table]
  ./oxconfig-mysql8-transition.sh verify <copy_table>
  ./oxconfig-mysql8-transition.sh dump <copy_table> [dump_file]
  CONFIRM_SWAP=1 ./oxconfig-mysql8-transition.sh swap <copy_table>

Run this script from the OXID Composer root directory.

Run create-copy before switching to MySQL 8 / before applying the OXID MySQL 8 patch,
while MySQL ENCODE()/DECODE() still exists.

Run swap only after the patch is installed. It renames:
  oxconfig -> oxconfig_encoded_backup_<timestamp>
  <copy_table> -> oxconfig

Environment:
  CONFIG_FILE    Defaults to source/config.inc.php
  MYSQL_BIN      Defaults to mysql
  MYSQLDUMP_BIN  Defaults to mysqldump
USAGE
}

if [[ -z "$MODE" || "$MODE" == "-h" || "$MODE" == "--help" ]]; then
    usage
    exit 0
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Config file not found: $CONFIG_FILE" >&2
    exit 1
fi

case "$MODE" in
    create-copy|verify|dump|swap)
        ;;
    *)
        echo "Unknown mode: $MODE" >&2
        usage
        exit 1
        ;;
esac

timestamp="$(date +%Y%m%d%H%M%S)"
if [[ -z "$TABLE_NAME" ]]; then
    TABLE_NAME="oxconfig_decoded_${timestamp}"
fi

if [[ ! "$TABLE_NAME" =~ ^[A-Za-z0-9_]+$ ]]; then
    echo "Unsafe table name: $TABLE_NAME" >&2
    exit 1
fi

tmp_defaults="$(mktemp)"
tmp_sql="$(mktemp)"
tmp_create_sql="$(mktemp)"
tmp_php="$(mktemp)"
tmp_mysql_output="$(mktemp)"
tmp_mysql_error="$(mktemp)"
tmp_db_name="$(mktemp)"
trap 'rm -f "$tmp_defaults" "$tmp_sql" "$tmp_create_sql" "$tmp_php" "$tmp_mysql_output" "$tmp_mysql_error" "$tmp_db_name"' EXIT
chmod 600 "$tmp_defaults"

cat > "$tmp_php" <<'PHP'
<?php
$configFile = $argv[1];
$defaultsFile = $argv[2];
$sqlFile = $argv[3];
$defaultConfigKey = $argv[4];
$dbNameFile = $argv[5];

$loader = new class {
    public function load(string $file): array
    {
        include $file;
        return get_object_vars($this);
    }
};

$config = $loader->load($configFile);

foreach (['dbHost', 'dbName', 'dbUser', 'dbPwd'] as $required) {
    if (!array_key_exists($required, $config)) {
        fwrite(STDERR, "Missing {$required} in {$configFile}\n");
        exit(1);
    }
}

$escapeOptionValue = static function ($value): string {
    return str_replace(["\\", "\n", "\r"], ["\\\\", "\\n", "\\r"], (string) $value);
};

$defaults = "[client]\n"
    . "host=" . $escapeOptionValue($config['dbHost']) . "\n"
    . (isset($config['dbPort']) ? "port=" . $escapeOptionValue($config['dbPort']) . "\n" : "")
    . "user=" . $escapeOptionValue($config['dbUser']) . "\n"
    . "password=" . $escapeOptionValue($config['dbPwd']) . "\n"
    . "default-character-set=utf8\n";

file_put_contents($defaultsFile, $defaults);
file_put_contents($dbNameFile, (string) $config['dbName']);

$configKey = $config['sConfigKey'] ?? $defaultConfigKey;
$sqlQuote = static function ($value): string {
    return "'" . str_replace(["\\", "'"], ["\\\\", "\\'"], (string) $value) . "'";
};

file_put_contents($sqlFile, "SET @oxid_config_key := " . $sqlQuote($configKey) . ";\n");
PHP

php "$tmp_php" "$CONFIG_FILE" "$tmp_defaults" "$tmp_sql" "$DEFAULT_CONFIG_KEY" "$tmp_db_name"
DB_NAME="$(cat "$tmp_db_name")"

if [[ ! "$DB_NAME" =~ ^[A-Za-z0-9_]+$ ]]; then
    echo "Unsafe database name: $DB_NAME" >&2
    exit 1
fi

mysql_exec() {
    "$MYSQL_BIN" --defaults-extra-file="$tmp_defaults" --database="$DB_NAME" "$@"
}

assert_decode_available() {
    if ! mysql_exec --batch --skip-column-names --execute \
        "SELECT IF(DECODE(ENCODE('oxid_mysql8_probe', 'probe_key'), 'probe_key') = 'oxid_mysql8_probe', 'ok', 'fail')" \
        > "$tmp_mysql_output" 2> "$tmp_mysql_error"; then
        echo "Could not run the MySQL ENCODE()/DECODE() probe." >&2
        echo "This is usually a database connection/configuration problem, not yet a DECODE() compatibility result." >&2
        cat "$tmp_mysql_error" >&2
        exit 1
    fi

    if ! grep -qx "ok" "$tmp_mysql_output"; then
        echo "MySQL ENCODE()/DECODE() is not available or does not behave as expected." >&2
        echo "create-copy must be run before switching to MySQL 8, on the old compatible DB server." >&2
        exit 1
    fi
}

assert_table_exists() {
    local table="$1"
    if ! mysql_exec --batch --skip-column-names --execute "SHOW TABLES LIKE '${table}'" | grep -qx "$table"; then
        echo "Table does not exist: $table" >&2
        exit 1
    fi
}

case "$MODE" in
    create-copy)
        assert_decode_available
        if mysql_exec --batch --skip-column-names --execute "SHOW TABLES LIKE '${TABLE_NAME}'" | grep -qx "$TABLE_NAME"; then
            echo "Target table already exists: $TABLE_NAME" >&2
            exit 1
        fi

        cat "$tmp_sql" > "$tmp_create_sql"
        cat >> "$tmp_create_sql" <<SQL
CREATE TABLE \`${TABLE_NAME}\` LIKE \`oxconfig\`;
INSERT INTO \`${TABLE_NAME}\`
    (OXID, OXSHOPID, OXMODULE, OXVARNAME, OXVARTYPE, OXVARVALUE)
SELECT
    OXID,
    OXSHOPID,
    OXMODULE,
    OXVARNAME,
    OXVARTYPE,
    DECODE(OXVARVALUE, @oxid_config_key)
FROM \`oxconfig\`;
SQL
        mysql_exec < "$tmp_create_sql"
        echo "Created decoded oxconfig copy: ${TABLE_NAME}"
        ;;

    verify)
        assert_table_exists "$TABLE_NAME"
        mysql_exec --table --execute "
SELECT 'oxconfig' AS table_name, COUNT(*) AS rows_count FROM oxconfig
UNION ALL
SELECT '${TABLE_NAME}' AS table_name, COUNT(*) AS rows_count FROM \`${TABLE_NAME}\`;
SELECT OXSHOPID, OXVARTYPE, OXVARVALUE
FROM \`${TABLE_NAME}\`
WHERE OXVARNAME = 'contactFormRequiredFields'
ORDER BY OXSHOPID;
"
        ;;

    dump)
        assert_table_exists "$TABLE_NAME"
        if [[ -z "$OUTPUT_FILE" ]]; then
            OUTPUT_FILE="${TABLE_NAME}.sql"
        fi
        "$MYSQLDUMP_BIN" --defaults-extra-file="$tmp_defaults" --no-tablespaces --skip-lock-tables "$DB_NAME" "$TABLE_NAME" > "$OUTPUT_FILE"
        echo "Wrote dump: ${OUTPUT_FILE}"
        ;;

    swap)
        assert_table_exists "$TABLE_NAME"
        if [[ "${CONFIRM_SWAP:-}" != "1" ]]; then
            echo "Refusing to swap without CONFIRM_SWAP=1." >&2
            echo "Command: CONFIRM_SWAP=1 $0 swap ${TABLE_NAME}" >&2
            exit 1
        fi
        backup_table="oxconfig_encoded_backup_${timestamp}"
        mysql_exec --execute "RENAME TABLE \`oxconfig\` TO \`${backup_table}\`, \`${TABLE_NAME}\` TO \`oxconfig\`;"
        echo "Swapped tables. Backup table: ${backup_table}"
        ;;
esac
