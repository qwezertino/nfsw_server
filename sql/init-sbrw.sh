#!/bin/bash
# This script is executed by the MySQL container during first initialization
# (docker-entrypoint-initdb.d). It imports SBRW schema and data with the
# correct database name substituted in place of the hardcoded 'soapbox'.
set -e

DB="${MYSQL_DATABASE:-nfs_world}"

echo "[init-sbrw] Importing SBRW schema and data into '${DB}'..."

for sql_file in $(ls /sbrw-sql/*.sql | sort); do
    echo "[init-sbrw] Importing $(basename "$sql_file")..."
    sed "s/USE soapbox;/USE \`${DB}\`;/gI" "$sql_file" \
        | mysql -u root -p"${MYSQL_ROOT_PASSWORD}" "${DB}"
done

echo "[init-sbrw] Renaming tables to UPPERCASE (Linux case-sensitivity fix)..."
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" "${DB}" -BN \
    -e "SELECT CONCAT('RENAME TABLE \`', TABLE_NAME, '\` TO \`', UPPER(TABLE_NAME), '\`;')
        FROM information_schema.TABLES WHERE TABLE_SCHEMA = '${DB}';" \
    | mysql -u root -p"${MYSQL_ROOT_PASSWORD}" "${DB}"

echo "[init-sbrw] Done."
