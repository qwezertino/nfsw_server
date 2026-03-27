#!/bin/sh
# Entrypoint for the Openfire container.
# Generates openfire.xml from template using environment variables,
# then starts Openfire — skipping the web setup wizard.
set -e

CONF_FILE="/sbrw/openfire/conf/openfire.xml"
TEMPLATE="/docker/openfire.xml.template"

# Only write the config if it hasn't been customized yet (or if forced)
if [ ! -f "$CONF_FILE" ] || grep -q '\${OPENFIRE_DB_HOST}' "$CONF_FILE" 2>/dev/null; then
    echo "[entrypoint] Writing openfire.xml from template..."
    mkdir -p "$(dirname "$CONF_FILE")"
    # envsubst replaces ${VAR} placeholders using current environment
    envsubst < "$TEMPLATE" > "$CONF_FILE"
    echo "[entrypoint] Done."
fi

exec bash bin/openfire.sh
