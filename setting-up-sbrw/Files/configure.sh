#!/bin/bash
# ============================================================
#  SBRW — Configure server parameters in MySQL
# ============================================================

DB_NAME="nfs_world"
DB_USER="nfs_user"
DB_PASS="qwerty123456"
DB_HOST="localhost"

echo ""
echo "============================================================"
echo "  SBRW Server Configuration"
echo "============================================================"
echo ""
echo "Press Enter to keep the current value (shown in brackets)."
echo ""

# --- Get current values from DB ---
current_ip=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" -sN "$DB_NAME" \
    -e "SELECT \`VALUE\` FROM parameter WHERE \`NAME\`='XMPP_IP' LIMIT 1;" 2>/dev/null)
current_port=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" -sN "$DB_NAME" \
    -e "SELECT \`VALUE\` FROM parameter WHERE \`NAME\`='SERVER_ADDRESS' LIMIT 1;" 2>/dev/null \
    | grep -oP ':\K[0-9]+$')
current_token=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" -sN "$DB_NAME" \
    -e "SELECT \`VALUE\` FROM parameter WHERE \`NAME\`='OPENFIRE_TOKEN' LIMIT 1;" 2>/dev/null)

# --- Prompt ---
read -rp "Server IP   [${current_ip:-not set}]: " NEW_IP
read -rp "Server port [${current_port:-4444}]: "  NEW_PORT
read -rp "Openfire secret key [${current_token:-not set}]: " NEW_TOKEN

# --- Apply defaults if empty ---
NEW_IP="${NEW_IP:-$current_ip}"
NEW_PORT="${NEW_PORT:-${current_port:-4444}}"
NEW_TOKEN="${NEW_TOKEN:-$current_token}"

if [[ -z "$NEW_IP" ]]; then
    echo ""
    echo "ERROR: IP address cannot be empty."
    exit 1
fi
if [[ -z "$NEW_TOKEN" ]]; then
    echo ""
    echo "ERROR: Openfire secret key cannot be empty."
    exit 1
fi

echo ""
echo "Applying configuration:"
echo "  IP            = $NEW_IP"
echo "  Port          = $NEW_PORT"
echo "  SERVER_ADDRESS= http://$NEW_IP:$NEW_PORT"
echo "  OPENFIRE_TOKEN= $NEW_TOKEN"
echo ""

mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" <<SQL
UPDATE parameter SET \`VALUE\` = 'false'                        WHERE \`NAME\` = 'ENABLE_REDIS';
UPDATE parameter SET \`VALUE\` = 'http://${NEW_IP}:${NEW_PORT}' WHERE \`NAME\` = 'SERVER_ADDRESS';
UPDATE parameter SET \`VALUE\` = '${NEW_TOKEN}'                 WHERE \`NAME\` = 'OPENFIRE_TOKEN';
UPDATE parameter SET \`VALUE\` = '${NEW_IP}'                    WHERE \`NAME\` = 'UDP_FREEROAM_IP';
UPDATE parameter SET \`VALUE\` = '${NEW_IP}'                    WHERE \`NAME\` = 'UDP_RACE_IP';
UPDATE parameter SET \`VALUE\` = '${NEW_IP}'                    WHERE \`NAME\` = 'XMPP_IP';
SQL

if [[ $? -eq 0 ]]; then
    echo "Done!"
else
    echo "ERROR: MySQL query failed. Check your DB credentials."
    exit 1
fi

# --- Fix Openfire REST API wildcard excludes (required for the plugin to work) ---
echo "Applying Openfire REST API fix (adminConsole.access.allow-wildcards-in-excludes=true)..."
sudo mysql openfire_nfs <<SQL 2>/dev/null
INSERT INTO ofProperty (name, propValue)
VALUES ('adminConsole.access.allow-wildcards-in-excludes', 'true')
ON DUPLICATE KEY UPDATE propValue='true';
INSERT INTO ofProperty (name, propValue)
VALUES ('plugin.restapi.enabled', 'true')
ON DUPLICATE KEY UPDATE propValue='true';
-- Enable IQ (non-SASL) authentication so game clients can log in without SASL
INSERT INTO ofProperty (name, propValue)
VALUES ('xmpp.auth.iqauth', 'true')
ON DUPLICATE KEY UPDATE propValue='true';
-- Disable stream management (can cause reconnect loops with old XMPP clients)
INSERT INTO ofProperty (name, propValue)
VALUES ('stream.management.active', 'false')
ON DUPLICATE KEY UPDATE propValue='false';
-- Disable XMPP audit log (performance overhead, not needed in production)
INSERT INTO ofProperty (name, propValue)
VALUES ('xmpp.audit.active', 'false')
ON DUPLICATE KEY UPDATE propValue='false';
SQL

if [[ $? -eq 0 ]]; then
    echo "Done!"
else
    echo "WARNING: Could not update openfire_nfs (needs sudo). Run manually:"
    echo "  sudo mysql openfire_nfs -e \"INSERT INTO ofProperty (name, propValue) VALUES ('adminConsole.access.allow-wildcards-in-excludes','true') ON DUPLICATE KEY UPDATE propValue='true';\""
fi

echo ""
echo "Restart the server for changes to take effect:"
echo "  bash /home/qwezert/nfsw_server/setting-up-sbrw/Files/start.sh --stop"
echo "  bash /home/qwezert/nfsw_server/setting-up-sbrw/Files/start.sh"
