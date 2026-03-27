#!/bin/bash
# Executed by the MariaDB container on first initialization (docker-entrypoint-initdb.d).

SBRW_DB="${MYSQL_DATABASE:-nfs_world}"
OF_DB="${OPENFIRE_DB_NAME:-openfire_nfs}"
export OF_DB MYSQL_USER SERVER_IP SERVER_PORT OPENFIRE_TOKEN MODDING_SERVER_ID

SQL()    { mariadb -u root -p"${MYSQL_ROOT_PASSWORD}" "$@"; }
SQLENV() { envsubst | SQL "$@"; }  # pipe through envsubst to expand ${VAR} in .sql files

echo "[init-sbrw] === Starting initialization ==="
echo "[init-sbrw] SBRW_DB=${SBRW_DB}  OF_DB=${OF_DB}  SERVER_IP=${SERVER_IP}"

# ── 1. Openfire DB + schema + properties ─────────────────────────────────────
echo "[init-sbrw] Creating Openfire database '${OF_DB}'..."
SQLENV        < /docker-sql/openfire-create-db.sql
SQL "${OF_DB}" < /openfire_mysql.sql
echo "[init-sbrw] Setting Openfire properties..."
SQLENV "${OF_DB}" < /docker-sql/openfire-properties.sql
echo "[init-sbrw] Openfire done."

# ── 2. SBRW schema + data ─────────────────────────────────────────────────────
echo "[init-sbrw] Importing SBRW schema and data into '${SBRW_DB}'..."
while IFS= read -r -d '' sql_file; do
    echo "[init-sbrw]   $(basename "$sql_file")"
    sed "s/USE soapbox;/USE \`${SBRW_DB}\`;/gI" "$sql_file" \
        | SQL "${SBRW_DB}" || echo "[init-sbrw]   WARNING: errors in $(basename "$sql_file") (ignored)"
done < <(find /sbrw-sql -maxdepth 1 -name "*.sql" -print0 | sort -z)

echo "[init-sbrw] Renaming tables to UPPERCASE..."
SQL "${SBRW_DB}" -BN \
    -e "SELECT CONCAT('RENAME TABLE \`', TABLE_NAME, '\` TO \`', UPPER(TABLE_NAME), '\`;')
        FROM information_schema.TABLES WHERE TABLE_SCHEMA = '${SBRW_DB}';" \
    | SQL "${SBRW_DB}" || true

# ── 3. PARAMETER values ───────────────────────────────────────────────────────
echo "[init-sbrw] Writing server PARAMETER values..."
export SERVER_PORT="${SERVER_PORT:-4444}" MODDING_SERVER_ID="${MODDING_SERVER_ID:-sbrw-private}"
SQLENV "${SBRW_DB}" < /docker-sql/sbrw-parameters.sql

echo "[init-sbrw] === All done ==="
