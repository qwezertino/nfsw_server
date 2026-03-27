#!/bin/sh
# Entrypoint for the configure service.
# Waits for MySQL to be ready, then writes all server parameters into both DBs.
# Runs inside Docker — DB_HOST is always the mysql service.
set -e

echo "[configure] Waiting for MySQL at ${DB_HOST}..."
until mysqladmin ping -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASS}" --silent 2>/dev/null; do
    sleep 2
done
echo "[configure] MySQL is ready."

# MySQL healthcheck passes as soon as the daemon starts, but docker-entrypoint
# init scripts (schema import) may still be running. Wait for the PARAMETER table.
echo "[configure] Waiting for ${DB_NAME}.PARAMETER table (init scripts may still be running)..."
until mysql -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" \
    -e 'SELECT 1 FROM PARAMETER LIMIT 1' 2>/dev/null; do
    sleep 3
done
echo "[configure] Schema ready."

echo "[configure] Configuring nfs_world parameters..."
mysql -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" <<SQL
UPDATE PARAMETER SET \`VALUE\` = 'false'                                              WHERE \`NAME\` = 'ENABLE_REDIS';
UPDATE PARAMETER SET \`VALUE\` = 'http://${SERVER_IP}:${SERVER_PORT}'                WHERE \`NAME\` = 'SERVER_ADDRESS';
UPDATE PARAMETER SET \`VALUE\` = '${OPENFIRE_TOKEN}'                                 WHERE \`NAME\` = 'OPENFIRE_TOKEN';
UPDATE PARAMETER SET \`VALUE\` = '${SERVER_IP}'                                      WHERE \`NAME\` = 'UDP_FREEROAM_IP';
UPDATE PARAMETER SET \`VALUE\` = '${SERVER_IP}'                                      WHERE \`NAME\` = 'UDP_RACE_IP';
UPDATE PARAMETER SET \`VALUE\` = '${SERVER_IP}'                                      WHERE \`NAME\` = 'XMPP_IP';
INSERT INTO PARAMETER (\`NAME\`, \`VALUE\`) VALUES ('MODDING_ENABLED', 'true')
    ON DUPLICATE KEY UPDATE \`VALUE\` = 'true';
INSERT INTO PARAMETER (\`NAME\`, \`VALUE\`) VALUES ('MODDING_BASE_PATH', 'http://${SERVER_IP}:8000')
    ON DUPLICATE KEY UPDATE \`VALUE\` = 'http://${SERVER_IP}:8000';
INSERT INTO PARAMETER (\`NAME\`, \`VALUE\`) VALUES ('MODDING_FEATURES', '')
    ON DUPLICATE KEY UPDATE \`VALUE\` = '';
INSERT INTO PARAMETER (\`NAME\`, \`VALUE\`) VALUES ('MODDING_SERVER_ID', '${MODDING_SERVER_ID:-sbrw-private}')
    ON DUPLICATE KEY UPDATE \`VALUE\` = '${MODDING_SERVER_ID:-sbrw-private}';
SQL
echo "[configure] nfs_world done."

echo "[configure] Waiting for Openfire to initialize ${OPENFIRE_DB_NAME:-openfire_nfs}..."
until mysql -h"${DB_HOST}" -uroot -p"${MYSQL_ROOT_PASSWORD:-root}" "${OPENFIRE_DB_NAME:-openfire_nfs}" \
    -e 'SELECT 1 FROM ofProperty LIMIT 1' 2>/dev/null; do
    sleep 3
done
echo "[configure] Openfire DB ready."

echo "[configure] Configuring Openfire properties..."
mysql -h"${DB_HOST}" -uroot -p"${MYSQL_ROOT_PASSWORD:-root}" "${OPENFIRE_DB_NAME:-openfire_nfs}" <<SQL
INSERT INTO ofProperty (name, propValue) VALUES ('plugin.restapi.enabled', 'true')
    ON DUPLICATE KEY UPDATE propValue = 'true';
INSERT INTO ofProperty (name, propValue) VALUES ('plugin.restapi.secret', '${OPENFIRE_TOKEN}')
    ON DUPLICATE KEY UPDATE propValue = '${OPENFIRE_TOKEN}';
INSERT INTO ofProperty (name, propValue) VALUES ('adminConsole.access.allow-wildcards-in-excludes', 'true')
    ON DUPLICATE KEY UPDATE propValue = 'true';
INSERT INTO ofProperty (name, propValue) VALUES ('xmpp.auth.iqauth', 'true')
    ON DUPLICATE KEY UPDATE propValue = 'true';
INSERT INTO ofProperty (name, propValue) VALUES ('stream.management.active', 'false')
    ON DUPLICATE KEY UPDATE propValue = 'false';
INSERT INTO ofProperty (name, propValue) VALUES ('xmpp.audit.active', 'false')
    ON DUPLICATE KEY UPDATE propValue = 'false';
SQL
echo "[configure] Openfire properties done."

echo "[configure] All configuration applied successfully."
