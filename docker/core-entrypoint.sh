#!/bin/sh
# Core entrypoint: pass DB connection as Thorntail system properties
# so they're resolved from container env vars at runtime (not baked in at build time).
exec java \
  -Dthorntail.datasources.data-sources.SoapBoxDS.connection-url="jdbc:mysql://${DB_HOST}:3306/${DB_NAME}" \
  -Dthorntail.datasources.data-sources.SoapBoxDS.user-name="${DB_USER}" \
  -Dthorntail.datasources.data-sources.SoapBoxDS.password="${DB_PASS}" \
  -Dthorntail.http.port="${SERVER_PORT:-4444}" \
  -jar core.jar
