#!/bin/sh
# Entrypoint for the Openfire container.
# Generates openfire.xml from template using environment variables,
# then starts Openfire — skipping the web setup wizard.
set -e

CONF_FILE="/sbrw/openfire/conf/openfire.xml"
TEMPLATE="/docker/openfire.xml.template"

# Write the config if it doesn't exist or if it doesn't contain the DB URL yet
if [ ! -f "$CONF_FILE" ] || ! grep -q 'serverURL' "$CONF_FILE" 2>/dev/null; then
    echo "[entrypoint] Writing openfire.xml from template..."
    mkdir -p "$(dirname "$CONF_FILE")"
    # envsubst replaces ${VAR} placeholders using current environment
    envsubst < "$TEMPLATE" > "$CONF_FILE"
    echo "[entrypoint] Done."
fi

exec bash bin/openfire.sh
