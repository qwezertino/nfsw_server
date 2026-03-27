#!/bin/bash
# ============================================================
#  SBRW Linux Build Script
#  Equivalent of build-script.bat, adapted for Linux/WSL
# ============================================================
set -e

REPOS="/home/qwezert/nfsw_server"
SELFDIR="$REPOS/sbrw"

# --- Database config (soapbox core) ---
DB_NAME="nfs_world"
DB_USER="nfs_user"
DB_PASS="qwerty123456"
DB_HOST="localhost"

# --- Server port ---
SERVER_PORT="4444"

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
# NOTE: uses --force so it's safe to re-run
# -------------------------------------------------------
if [[ "${1}" == "--init-db" ]]; then
    step "Setting up databases..."

    # Openfire needs its own DB (configured via web UI later)
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" \
        -e "CREATE DATABASE IF NOT EXISTS openfire_nfs DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;" 2>/dev/null || true

    # Import soapbox schema into nfs_world
    echo "  Importing schema (2. Schema.sql)..."
    sed "s/USE soapbox;/USE \`$DB_NAME\`;/gI" \
        "$REPOS/setting-up-sbrw/Files/MySQL scripts/2. Schema.sql" \
        | mysql --force -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" 2>/dev/null || true

    echo "  Importing data   (3. Data.sql)..."
    sed "s/USE soapbox;/USE \`$DB_NAME\`;/gI" \
        "$REPOS/setting-up-sbrw/Files/MySQL scripts/3. Data.sql" \
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
cd "$REPOS/soapbox-race-core"
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
cd "$REPOS/freeroam/cmd/freeroamd"
go build -o freeroamd freeroamd.go
cp -f "freeroamd" "$SELFDIR/freeroam/freeroamd"
chmod +x "$SELFDIR/freeroam/freeroamd"
# config.toml is auto-generated on first startup if absent
echo "  Freeroam built => $SELFDIR/freeroam/freeroamd"

# -------------------------------------------------------
# Copy Race (sbrw-mp, pre-built jar)
# -------------------------------------------------------
step "Copying Race server (sbrw-mp)..."
cp -f "$REPOS/sbrw-mp-sync-2018/sbrw-mp.jar" "$SELFDIR/race/race.jar"
echo "  Race copied => $SELFDIR/race/race.jar"

# -------------------------------------------------------
# Download Openfire 4.9.2 pre-built distribution
# -------------------------------------------------------
OPENFIRE_VERSION="4_9_2"
OPENFIRE_TARBALL="openfire_${OPENFIRE_VERSION}.tar.gz"
OPENFIRE_URL="https://github.com/igniterealtime/Openfire/releases/download/v${OPENFIRE_VERSION//_/.}/${OPENFIRE_TARBALL}"

step "Downloading Openfire ${OPENFIRE_VERSION//_/.}..."
cd /tmp
if [[ ! -f "$OPENFIRE_TARBALL" ]]; then
    curl -L -o "$OPENFIRE_TARBALL" "$OPENFIRE_URL"
fi
rm -rf "$SELFDIR/openfire"
mkdir -p "$SELFDIR/openfire"
tar -xzf "$OPENFIRE_TARBALL" --strip-components=1 -C "$SELFDIR/openfire"
chmod +x "$SELFDIR/openfire/bin/openfire.sh"
# Bind admin console to all interfaces so it's reachable from outside (incl. Windows/remote)
sed -i 's|<interface>127.0.0.1</interface>|<interface>0.0.0.0</interface>|g' "$SELFDIR/openfire/conf/openfire.xml" 2>/dev/null || true
# Enable TLSv1/TLSv1.1 in Java 11 for the old NFS World game client (uses TLSv1 for XMPP)
JAVA11_SECURITY="/usr/lib/jvm/java-11-openjdk-amd64/conf/security/java.security"
if [[ -f "$JAVA11_SECURITY" ]]; then
    sudo sed -i 's/jdk.tls.disabledAlgorithms=SSLv3, TLSv1, TLSv1.1, DTLSv1.0,/jdk.tls.disabledAlgorithms=SSLv3, DTLSv1.0,/' "$JAVA11_SECURITY" 2>/dev/null || true
    echo "  TLSv1 enabled in Java 11 security policy"
fi
echo "  Openfire 4.9.2 => $SELFDIR/openfire/"

# -------------------------------------------------------
# Build Openfire RestAPI plugin
# -------------------------------------------------------
step "Building Openfire RestAPI Plugin..."
cd "$REPOS/openfire-restAPI-plugin"
mvn clean package -q -DskipTests
cp -f "target/restAPI-openfire-plugin-assembly.jar" "$SELFDIR/openfire/plugins/restAPI.jar"
echo "  RestAPI Plugin => $SELFDIR/openfire/plugins/restAPI.jar"

# -------------------------------------------------------
# Build Openfire Non-SASL Auth plugin
# -------------------------------------------------------
step "Building Openfire Non-SASL Auth Plugin..."
cd "$REPOS/openfire-nonSaslAuthentication-plugin"
mvn clean package -q -DskipTests
cp -f "target/nonSaslAuthentication-openfire-plugin-assembly.jar" "$SELFDIR/openfire/plugins/nonSaslAuthentication.jar"
echo "  Non-SASL Plugin => $SELFDIR/openfire/plugins/nonSaslAuthentication.jar"

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
