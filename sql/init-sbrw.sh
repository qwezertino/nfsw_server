#!/bin/bash
# Executed by the MySQL container on first initialization (docker-entrypoint-initdb.d).
# Handles everything in one pass — no separate configure service needed.
set -e

SBRW_DB="${MYSQL_DATABASE:-nfs_world}"
OF_DB="${OPENFIRE_DB_NAME:-openfire_nfs}"

# ── 1. Openfire database + ofProperty table + properties ─────────────────────
echo "[init-sbrw] Creating Openfire database '${OF_DB}'..."
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<SQL
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
echo "[init-sbrw] Openfire DB ready."

# ── 2. SBRW schema + data ─────────────────────────────────────────────────────
echo "[init-sbrw] Importing SBRW schema and data into '${SBRW_DB}'..."
for sql_file in $(ls /sbrw-sql/*.sql | sort); do
    echo "[init-sbrw]   $(basename "$sql_file")"
    sed "s/USE soapbox;/USE \`${SBRW_DB}\`;/gI" "$sql_file" \
        | mysql -u root -p"${MYSQL_ROOT_PASSWORD}" "${SBRW_DB}"
done

echo "[init-sbrw] Renaming tables to UPPERCASE (Linux case-sensitivity fix)..."
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" "${SBRW_DB}" -BN \
    -e "SELECT CONCAT('RENAME TABLE \`', TABLE_NAME, '\` TO \`', UPPER(TABLE_NAME), '\`;')
        FROM information_schema.TABLES WHERE TABLE_SCHEMA = '${SBRW_DB}';" \
    | mysql -u root -p"${MYSQL_ROOT_PASSWORD}" "${SBRW_DB}"

# ── 3. PARAMETER values ───────────────────────────────────────────────────────
echo "[init-sbrw] Writing server PARAMETER values..."
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" "${SBRW_DB}" <<SQL
UPDATE PARAMETER SET \`VALUE\` = 'false'                          WHERE \`NAME\` = 'ENABLE_REDIS';
UPDATE PARAMETER SET \`VALUE\` = 'http://${SERVER_IP}:${SERVER_PORT:-4444}' WHERE \`NAME\` = 'SERVER_ADDRESS';
UPDATE PARAMETER SET \`VALUE\` = '${OPENFIRE_TOKEN}'              WHERE \`NAME\` = 'OPENFIRE_TOKEN';
UPDATE PARAMETER SET \`VALUE\` = '${SERVER_IP}'                   WHERE \`NAME\` = 'UDP_FREEROAM_IP';
UPDATE PARAMETER SET \`VALUE\` = '${SERVER_IP}'                   WHERE \`NAME\` = 'UDP_RACE_IP';
UPDATE PARAMETER SET \`VALUE\` = '${SERVER_IP}'                   WHERE \`NAME\` = 'XMPP_IP';
INSERT INTO PARAMETER (\`NAME\`, \`VALUE\`) VALUES ('MODDING_ENABLED', 'true')
    ON DUPLICATE KEY UPDATE \`VALUE\` = 'true';
INSERT INTO PARAMETER (\`NAME\`, \`VALUE\`) VALUES ('MODDING_BASE_PATH', 'http://${SERVER_IP}:8000')
    ON DUPLICATE KEY UPDATE \`VALUE\` = 'http://${SERVER_IP}:8000';
INSERT INTO PARAMETER (\`NAME\`, \`VALUE\`) VALUES ('MODDING_FEATURES', '')
    ON DUPLICATE KEY UPDATE \`VALUE\` = '';
INSERT INTO PARAMETER (\`NAME\`, \`VALUE\`) VALUES ('MODDING_SERVER_ID', '${MODDING_SERVER_ID:-sbrw-private}')
    ON DUPLICATE KEY UPDATE \`VALUE\` = '${MODDING_SERVER_ID:-sbrw-private}';
SQL

echo "[init-sbrw] All done."
