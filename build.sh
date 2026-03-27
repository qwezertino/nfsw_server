#!/bin/bash
# ============================================================
#  SBRW Linux Build Script
#  Equivalent of build-script.bat, adapted for Linux/WSL
# ============================================================
set -e

# Resolve repo root relative to this script — works both on host and inside Docker
REPOS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELFDIR="$REPOS/sbrw"

# Load .env if present (overrides defaults below)
if [[ -f "$REPOS/.env" ]]; then
    set -a
    source "$REPOS/.env"
    set +a
fi

# --- Database config (soapbox core) ---
DB_NAME="${DB_NAME:-nfs_world}"
DB_USER="${DB_USER:-nfs_user}"
DB_PASS="${DB_PASS:-qwerty123456}"
DB_HOST="${DB_HOST:-localhost}"

# --- Server port ---
SERVER_PORT="${SERVER_PORT:-4444}"

# -------------------------------------------------------
# Helper: print step header
# -------------------------------------------------------
step() { echo ""; echo ">>> $*"; }

# -------------------------------------------------------
# Create output directory tree
# -------------------------------------------------------
step "Creating output directories..."
mkdir -p "$SELFDIR/core"
mkdir -p "$SELFDIR/freeroam"
mkdir -p "$SELFDIR/race/keys"
mkdir -p "$SELFDIR/openfire/plugins"

# -------------------------------------------------------
# Optional: initialize / re-import the database schema.
# Pass --init-db as the first argument to enable this.
#
# NOTE: This is for LOCAL / tmux development only.
#       In Docker, sql/init-sbrw.sh runs automatically on
#       first MySQL container creation — no --init-db needed.
# -------------------------------------------------------
if [[ "${1}" == "--init-db" ]]; then
    step "Setting up databases..."

    # Openfire needs its own DB (configured via web UI later)
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" \
        -e "CREATE DATABASE IF NOT EXISTS openfire_nfs DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;" 2>/dev/null || true

    # Import soapbox schema into nfs_world
    echo "  Importing schema (2. Schema.sql)..."
    sed "s/USE soapbox;/USE \`$DB_NAME\`;/gI" \
        "$REPOS/sql/mysql/2. Schema.sql" \
        | mysql --force -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" 2>/dev/null || true

    echo "  Importing data   (3. Data.sql)..."
    sed "s/USE soapbox;/USE \`$DB_NAME\`;/gI" \
        "$REPOS/sql/mysql/3. Data.sql" \
        | mysql --force -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" 2>/dev/null || true

    echo "  Renaming tables to UPPERCASE (Linux case-sensitivity fix)..."
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -BN \
        -e "SELECT CONCAT('RENAME TABLE \`', TABLE_NAME, '\` TO \`', UPPER(TABLE_NAME), '\`;') FROM information_schema.TABLES WHERE TABLE_SCHEMA = '$DB_NAME';" 2>/dev/null \
        | mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" 2>/dev/null || true

    echo "  Database setup complete."
fi

# -------------------------------------------------------
# Build soapbox-race-core  (Thorntail / Java)
# -------------------------------------------------------
step "Building SBRW-Core (Maven)..."
cd "$REPOS/src/soapbox-race-core"
mvn clean package -q -DskipTests
cp -f "target/core-thorntail.jar" "$SELFDIR/core/core.jar"

# Write a configured project-defaults.yml into the output dir
cat > "$SELFDIR/core/project-defaults.yml" <<YAML
thorntail:
  http:
    port: ${SERVER_PORT}
  datasources:
    data-sources:
      SoapBoxDS:
        driver-name: mysql
        connection-url: jdbc:mysql://${DB_HOST}:3306/${DB_NAME}
        user-name: ${DB_USER}
        password: ${DB_PASS}
        valid-connection-checker-class-name: org.jboss.jca.adapters.jdbc.extensions.mysql.MySQLValidConnectionChecker
        validate-on-match: true
        background-validation: false
        exception-sorter-class-name: org.jboss.jca.adapters.jdbc.extensions.mysql.MySQLExceptionSorter
        max-pool-size: 64
        min-pool-size: 8
        share-prepared-statements: true
  mail:
    mail-sessions:
      Gmail:
        smtp-server:
          username: serveremailhere@gmail.com
          password: secret
          ssl: true
    smtp:
      host: smtp.gmail.com
      port: 465
  undertow:
    filter-configuration:
      response-headers:
      # reserved for future use
      gzips:
        gzipFilter:
        # nothing to configure
    servers:
      default-server:
        hosts:
          default-host:
            filter-refs:
              gzipFilter:
                priority: 1
                predicate: "exists['%{o,Content-Type}'] and regex[pattern='(?:application/javascript|text/css|text/html|text/xml|application/json|application/xml)(;.*)?', value=%{o,Content-Type}, full-match=true]"
YAML

echo "  SBRW-Core built => $SELFDIR/core/core.jar"

# -------------------------------------------------------
# Build Freeroam  (Go)
# -------------------------------------------------------
step "Building Freeroam server (Go)..."
cd "$REPOS/src/freeroam/cmd/freeroamd"
go build -o freeroamd freeroamd.go
cp -f "freeroamd" "$SELFDIR/freeroam/freeroamd"
chmod +x "$SELFDIR/freeroam/freeroamd"
# config.toml is auto-generated on first startup if absent
echo "  Freeroam built => $SELFDIR/freeroam/freeroamd"

# -------------------------------------------------------
# Copy Race (sbrw-mp, pre-built jar)
# -------------------------------------------------------
step "Copying Race server (sbrw-mp)..."
cp -f "$REPOS/src/sbrw-mp-sync-2018/sbrw-mp.jar" "$SELFDIR/race/race.jar"
echo "  Race copied => $SELFDIR/race/race.jar"

# -------------------------------------------------------
# Build SBRW Openfire fork (4.5.0-SNAPSHOT) from source
# -------------------------------------------------------
OPENFIRE_SRC="$REPOS/src/openfire"
# Inside Dockerfile.builder Java 8 is the default JDK; on host override via JAVA8_HOME env var
JAVA8_HOME="${JAVA8_HOME:-${JAVA_HOME:-/opt/java/openjdk}}"

step "Building SBRW Openfire fork (4.5.0-SNAPSHOT)..."
cd "$OPENFIRE_SRC"
JAVA_HOME="$JAVA8_HOME" mvn install -pl xmppserver -am -DskipTests -q
JAVA_HOME="$JAVA8_HOME" mvn package -pl distribution -am -DskipTests -q

rm -rf "$SELFDIR/openfire"
mkdir -p "$SELFDIR/openfire/plugins"
cp -r "$OPENFIRE_SRC/distribution/target/distribution-base/." "$SELFDIR/openfire/"
chmod +x "$SELFDIR/openfire/bin/openfire.sh"
# Bind admin console to all interfaces so it's reachable from outside (incl. Windows/remote)
sed -i 's|<interface>127.0.0.1</interface>|<interface>0.0.0.0</interface>|g' "$SELFDIR/openfire/conf/openfire.xml" 2>/dev/null || true
# Enable TLSv1/TLSv1.1 in Java 11 for the old NFS World game client (uses TLSv1 for XMPP)
JAVA11_SECURITY="/usr/lib/jvm/java-11-openjdk-amd64/conf/security/java.security"
if [[ -f "$JAVA11_SECURITY" ]]; then
    sudo sed -i 's/jdk.tls.disabledAlgorithms=SSLv3, TLSv1, TLSv1.1, DTLSv1.0,/jdk.tls.disabledAlgorithms=SSLv3, DTLSv1.0,/' "$JAVA11_SECURITY" 2>/dev/null || true
    echo "  TLSv1 enabled in Java 11 security policy"
fi
echo "  SBRW Openfire 4.5.0-SNAPSHOT => $SELFDIR/openfire/"

# -------------------------------------------------------
# Download Openfire plugins (prebuilt, compatible with 4.5.0)
# -------------------------------------------------------
step "Downloading Openfire plugins..."
curl -sSL -o "$SELFDIR/openfire/plugins/restAPI.jar" \
    "https://www.igniterealtime.org/projects/openfire/plugins/1.4.0/restAPI.jar"
echo "  RestAPI 1.4.0 => $SELFDIR/openfire/plugins/restAPI.jar"

curl -sSL -o "$SELFDIR/openfire/plugins/nonSaslAuthentication.jar" \
    "https://www.igniterealtime.org/projects/openfire/plugins/1.0.1/nonSaslAuthentication.jar"
echo "  NonSaslAuthentication 1.0.1 => $SELFDIR/openfire/plugins/nonSaslAuthentication.jar"

# -------------------------------------------------------
# Create ModNet static server content
# -------------------------------------------------------
step "Creating ModNet index..."
mkdir -p "$SELFDIR/modnet"
cat > "$SELFDIR/modnet/index.json" <<'JSON'
{
    "built_at": "2021-02-28T23:01:24.394847+03:00",
    "entries": []
}
JSON
echo "  ModNet index => $SELFDIR/modnet/index.json"

# -------------------------------------------------------
# Done
# -------------------------------------------------------
echo ""
echo "============================================================"
echo "  Build Complete!"
echo "============================================================"
echo ""
echo "Output directory: $SELFDIR"
echo ""
echo "Next steps:"
echo ""
echo "  1. Initialize DB schema (first time only):"
echo "       bash $REPOS/setting-up-sbrw/Files/build.sh --init-db"
echo ""
echo "  2. Start all servers:"
echo "       bash $REPOS/setting-up-sbrw/Files/start.sh"
echo ""
echo "  3. Configure Openfire via browser (first time only):"
echo "       http://localhost:9090/setup/index.jsp"
echo "       DB settings: host=localhost, db=openfire_nfs, user=$DB_USER, pass=<your openfire db pass>"
echo ""
echo "  4. After Openfire is set up, update the 'parameter' table"
echo "     in the '$DB_NAME' database:"
echo "     - SERVER_ADDRESS   => http://YOUR_IP:$SERVER_PORT"
echo "     - OPENFIRE_TOKEN   => (secret key from Openfire REST API settings)"
echo "     - UDP_FREEROAM_IP  => YOUR_IP"
echo "     - UDP_RACE_IP      => YOUR_IP"
echo "     - XMPP_IP          => YOUR_IP"
echo "     - ENABLE_REDIS     => false"
echo ""
