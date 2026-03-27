#!/bin/bash
# Executed by the MariaDB container on first initialization (docker-entrypoint-initdb.d).
# Runs as unix root inside the container — no password needed (unix_socket auth).

SBRW_DB="${MYSQL_DATABASE:-nfs_world}"
OF_DB="${OPENFIRE_DB_NAME:-openfire_nfs}"

# Connect as root with password (MariaDB 11 requires it even in init context)
SQL() { mariadb -u root -p"${MYSQL_ROOT_PASSWORD}" "$@"; }

echo "[init-sbrw] === Starting initialization ==="
echo "[init-sbrw] SBRW_DB=${SBRW_DB}  OF_DB=${OF_DB}  SERVER_IP=${SERVER_IP}"

# ── 1. Openfire database + ofProperty ────────────────────────────────────────
echo "[init-sbrw] Creating Openfire database '${OF_DB}'..."
SQL <<SQL
CREATE DATABASE IF NOT EXISTS \`${OF_DB}\`
  DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON \`${OF_DB}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
USE \`${OF_DB}\`;

CREATE TABLE IF NOT EXISTS ofProperty (
  name       VARCHAR(100) NOT NULL,
  propValue  TEXT         NOT NULL,
  encrypted  TINYINT      NOT NULL DEFAULT 0,
  iv         VARCHAR(24),
  CONSTRAINT ofProperty_pk PRIMARY KEY (name)
);

INSERT INTO ofProperty (name, propValue) VALUES ('plugin.restapi.enabled',  'true')
    ON DUPLICATE KEY UPDATE propValue = 'true';
INSERT INTO ofProperty (name, propValue) VALUES ('plugin.restapi.secret',   '${OPENFIRE_TOKEN}')
    ON DUPLICATE KEY UPDATE propValue = '${OPENFIRE_TOKEN}';
INSERT INTO ofProperty (name, propValue) VALUES ('xmpp.auth.iqauth',        'true')
    ON DUPLICATE KEY UPDATE propValue = 'true';
INSERT INTO ofProperty (name, propValue) VALUES ('stream.management.active','false')
    ON DUPLICATE KEY UPDATE propValue = 'false';
INSERT INTO ofProperty (name, propValue) VALUES ('xmpp.audit.active',       'false')
    ON DUPLICATE KEY UPDATE propValue = 'false';
INSERT INTO ofProperty (name, propValue) VALUES ('adminConsole.access.allow-wildcards-in-excludes','true')
    ON DUPLICATE KEY UPDATE propValue = 'true';
SQL
echo "[init-sbrw] Openfire DB done."

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
SQL "${SBRW_DB}" <<SQL
UPDATE PARAMETER SET \`VALUE\` = 'false'                                    WHERE \`NAME\` = 'ENABLE_REDIS';
UPDATE PARAMETER SET \`VALUE\` = 'http://${SERVER_IP}:${SERVER_PORT:-4444}' WHERE \`NAME\` = 'SERVER_ADDRESS';
UPDATE PARAMETER SET \`VALUE\` = '${OPENFIRE_TOKEN}'                        WHERE \`NAME\` = 'OPENFIRE_TOKEN';
UPDATE PARAMETER SET \`VALUE\` = '${SERVER_IP}'                             WHERE \`NAME\` = 'UDP_FREEROAM_IP';
UPDATE PARAMETER SET \`VALUE\` = '${SERVER_IP}'                             WHERE \`NAME\` = 'UDP_RACE_IP';
UPDATE PARAMETER SET \`VALUE\` = '${SERVER_IP}'                             WHERE \`NAME\` = 'XMPP_IP';
INSERT INTO PARAMETER (\`NAME\`, \`VALUE\`) VALUES ('MODDING_ENABLED', 'true')
    ON DUPLICATE KEY UPDATE \`VALUE\` = 'true';
INSERT INTO PARAMETER (\`NAME\`, \`VALUE\`) VALUES ('MODDING_BASE_PATH', 'http://${SERVER_IP}:8000')
    ON DUPLICATE KEY UPDATE \`VALUE\` = 'http://${SERVER_IP}:8000';
INSERT INTO PARAMETER (\`NAME\`, \`VALUE\`) VALUES ('MODDING_FEATURES', '')
    ON DUPLICATE KEY UPDATE \`VALUE\` = '';
INSERT INTO PARAMETER (\`NAME\`, \`VALUE\`) VALUES ('MODDING_SERVER_ID', '${MODDING_SERVER_ID:-sbrw-private}')
    ON DUPLICATE KEY UPDATE \`VALUE\` = '${MODDING_SERVER_ID:-sbrw-private}';
SQL

echo "[init-sbrw] === All done ==="
