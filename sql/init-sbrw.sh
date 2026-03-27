#!/bin/bash
# Executed by the MariaDB container on first initialization (docker-entrypoint-initdb.d).

SBRW_DB="${MYSQL_DATABASE:-nfs_world}"
OF_DB="${OPENFIRE_DB_NAME:-openfire_nfs}"
export OF_DB MYSQL_USER SERVER_IP SERVER_PORT OPENFIRE_TOKEN MODDING_SERVER_ID

SQL()    { mariadb -u root -p"${MYSQL_ROOT_PASSWORD}" "$@"; }
# Substitute all known ${VAR} placeholders without requiring envsubst
SQLENV() { sed \
    -e "s|\${SERVER_IP}|${SERVER_IP}|g" \
    -e "s|\${SERVER_PORT}|${SERVER_PORT}|g" \
    -e "s|\${OPENFIRE_TOKEN}|${OPENFIRE_TOKEN}|g" \
    -e "s|\${MODDING_SERVER_ID}|${MODDING_SERVER_ID}|g" \
    | SQL "$@"; }

echo "[init-sbrw] === Starting initialization ==="
echo "[init-sbrw] SBRW_DB=${SBRW_DB}  OF_DB=${OF_DB}  SERVER_IP=${SERVER_IP}"

# ── 1. SBRW schema + data ─────────────────────────────────────────────────────
# base.sql runs first and creates the openfire_nfs DB (+ grants)
echo "[init-sbrw] Importing SBRW schema and data into '${SBRW_DB}'..."
for sql_file in /sbrw-sql/base.sql /sbrw-sql/schema.sql /sbrw-sql/data.sql; do
    echo "[init-sbrw]   $(basename "$sql_file")"
    sed "s/USE soapbox;/USE \`${SBRW_DB}\`;/gI" "$sql_file" \
        | SQL "${SBRW_DB}" || echo "[init-sbrw]   WARNING: errors in $(basename "$sql_file") (ignored)"
done

echo "[init-sbrw] Renaming tables to UPPERCASE..."
SQL "${SBRW_DB}" -BN \
    -e "SELECT CONCAT('RENAME TABLE \`', TABLE_NAME, '\` TO \`', UPPER(TABLE_NAME), '\`;')
        FROM information_schema.TABLES WHERE TABLE_SCHEMA = '${SBRW_DB}';" \
    | SQL "${SBRW_DB}" || true

# ── 2. Openfire schema + properties ──────────────────────────────────────────
# openfire_nfs was just created by base.sql above
echo "[init-sbrw] Importing Openfire schema into '${OF_DB}'..."
SQL "${OF_DB}" < /openfire_mysql.sql
echo "[init-sbrw] Setting Openfire properties..."
SQLENV "${OF_DB}" < /docker-sql/openfire-properties.sql

# ── 3. PARAMETER values ───────────────────────────────────────────────────────
echo "[init-sbrw] Writing server PARAMETER values..."
export SERVER_PORT="${SERVER_PORT:-4444}" MODDING_SERVER_ID="${MODDING_SERVER_ID:-sbrw-private}"
SQLENV "${SBRW_DB}" < /docker-sql/sbrw-parameters.sql

echo "[init-sbrw] === All done ==="
