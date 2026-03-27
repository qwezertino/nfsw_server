#!/bin/bash
# ============================================================
#  SBRW — Configure server parameters in MySQL from .env
# ============================================================
set -e

REPOS="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$REPOS/.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: .env not found. Create it first:"
    echo "  cp $REPOS/.env.example $REPOS/.env"
    echo "  nano $REPOS/.env"
    exit 1
fi

# Load .env
set -a
source "$ENV_FILE"
set +a

# Validate required vars
for var in SERVER_IP SERVER_PORT DB_HOST DB_NAME DB_USER DB_PASS OPENFIRE_TOKEN; do
    if [[ -z "${!var}" ]]; then
        echo "ERROR: $var is not set in .env"
        exit 1
    fi
done

if [[ "$OPENFIRE_TOKEN" == "changeme" ]]; then
    echo "ERROR: OPENFIRE_TOKEN is still set to 'changeme'."
    echo "  Get the token from Openfire admin console → Server → Server Settings → REST API"
    exit 1
fi

echo ""
echo "============================================================"
echo "  Applying SBRW configuration from .env"
echo "============================================================"
echo "  IP             = $SERVER_IP"
echo "  PORT           = $SERVER_PORT"
echo "  SERVER_ADDRESS = http://$SERVER_IP:$SERVER_PORT"
echo "  OPENFIRE_TOKEN = $OPENFIRE_TOKEN"
echo "  MODDING_BASE   = http://$SERVER_IP:8000"
echo ""

mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" <<SQL
UPDATE PARAMETER SET \`VALUE\` = 'false'                               WHERE \`NAME\` = 'ENABLE_REDIS';
UPDATE PARAMETER SET \`VALUE\` = 'http://${SERVER_IP}:${SERVER_PORT}' WHERE \`NAME\` = 'SERVER_ADDRESS';
UPDATE PARAMETER SET \`VALUE\` = '${OPENFIRE_TOKEN}'                  WHERE \`NAME\` = 'OPENFIRE_TOKEN';
UPDATE PARAMETER SET \`VALUE\` = '${SERVER_IP}'                       WHERE \`NAME\` = 'UDP_FREEROAM_IP';
UPDATE PARAMETER SET \`VALUE\` = '${SERVER_IP}'                       WHERE \`NAME\` = 'UDP_RACE_IP';
UPDATE PARAMETER SET \`VALUE\` = '${SERVER_IP}'                       WHERE \`NAME\` = 'XMPP_IP';
INSERT INTO PARAMETER (\`NAME\`, \`VALUE\`) VALUES ('MODDING_ENABLED', 'true')
    ON DUPLICATE KEY UPDATE \`VALUE\` = 'true';
INSERT INTO PARAMETER (\`NAME\`, \`VALUE\`) VALUES ('MODDING_BASE_PATH', 'http://${SERVER_IP}:8000')
    ON DUPLICATE KEY UPDATE \`VALUE\` = 'http://${SERVER_IP}:8000'\;
INSERT INTO PARAMETER (\`NAME\`, \`VALUE\`) VALUES ('MODDING_FEATURES', '')
    ON DUPLICATE KEY UPDATE \`VALUE\` = '';
INSERT INTO PARAMETER (\`NAME\`, \`VALUE\`) VALUES ('MODDING_SERVER_ID', '${MODDING_SERVER_ID:-sbrw-private}')
    ON DUPLICATE KEY UPDATE \`VALUE\` = '${MODDING_SERVER_ID:-sbrw-private}';
SQL

echo "  nfs_world parameters updated."

# --- Openfire DB properties ---
sudo mysql "${OPENFIRE_DB_NAME:-openfire_nfs}" <<SQL 2>/dev/null
INSERT INTO ofProperty (name, propValue) VALUES ('adminConsole.access.allow-wildcards-in-excludes', 'true')
    ON DUPLICATE KEY UPDATE propValue='true';
INSERT INTO ofProperty (name, propValue) VALUES ('plugin.restapi.enabled', 'true')
    ON DUPLICATE KEY UPDATE propValue='true';
INSERT INTO ofProperty (name, propValue) VALUES ('xmpp.auth.iqauth', 'true')
    ON DUPLICATE KEY UPDATE propValue='true';
INSERT INTO ofProperty (name, propValue) VALUES ('stream.management.active', 'false')
    ON DUPLICATE KEY UPDATE propValue='false';
INSERT INTO ofProperty (name, propValue) VALUES ('xmpp.audit.active', 'false')
    ON DUPLICATE KEY UPDATE propValue='false';
SQL

echo "  openfire_nfs properties updated."
echo ""
echo "Done! Restart core to apply changes:"
echo "  docker compose restart core   (Docker)"
echo "  bash $REPOS/start.sh --stop && bash $REPOS/start.sh   (tmux)"
