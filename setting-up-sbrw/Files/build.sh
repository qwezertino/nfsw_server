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
# Surgically patch Openfire 4.9.2 to fix the 2-minute "lost connection"
# hang for NFS World game clients.
#
# Root cause: Openfire offers SASL mechanisms to ALL C2S connections.
# The NFS World game client (circa 2010) attempts SASL, times out after
# ~2 minutes, then falls back to IQ auth (jabber:iq:auth) and succeeds.
#
# Fix: patch getSASLMechanisms() to return null (no SASL) for connections
# where the stream 'from' attribute does NOT contain ".engine.engine".
# soapbox-race-core connects as "sbrw.engine.engine@<ip>" so it still gets
# SASL; game clients get none and jump straight to IQ auth.
#
# Files patched inside xmppserver-4.9.2.jar:
#   org/jivesoftware/openfire/net/SASLAuthentication.class  (new overload)
#   org/jivesoftware/openfire/session/LocalClientSession.class (call new overload)
# -------------------------------------------------------
step "Applying SBRW SASL patch to Openfire 4.9.2..."

PATCH_DIR="/tmp/openfire-sbrw-patch-$$"
OF_LIB="$SELFDIR/openfire/lib"
OF_JAR="$OF_LIB/xmppserver-4.9.2.jar"
JAVA11_BIN="/usr/lib/jvm/java-1.11.0-openjdk-amd64/bin"

# Build classpath from all JARs in openfire/lib
OF_CP=$(find "$OF_LIB" -name "*.jar" | tr '\n' ':')

mkdir -p "$PATCH_DIR/src/org/jivesoftware/openfire/net"
mkdir -p "$PATCH_DIR/src/org/jivesoftware/openfire/session"
mkdir -p "$PATCH_DIR/classes"

# Download source files from Openfire 4.9.2 tag
echo "  Downloading source files from Openfire 4.9.2 GitHub..."
RAW="https://raw.githubusercontent.com/igniterealtime/Openfire/v4.9.2/xmppserver/src/main/java/org/jivesoftware/openfire"
curl -sfL -o "$PATCH_DIR/src/org/jivesoftware/openfire/net/SASLAuthentication.java" \
  "$RAW/net/SASLAuthentication.java"
curl -sfL -o "$PATCH_DIR/src/org/jivesoftware/openfire/session/LocalClientSession.java" \
  "$RAW/session/LocalClientSession.java"

# Patch SASLAuthentication.java:
#   1. Add XmlPullParser import
#   2. Add new getSASLMechanisms(LocalSession, XmlPullParser) overload that
#      only offers SASL when the stream 'from' contains ".engine.engine"
echo "  Patching SASLAuthentication.java..."
python3 - "$PATCH_DIR/src/org/jivesoftware/openfire/net/SASLAuthentication.java" << 'PYEOF'
import sys

filepath = sys.argv[1]
with open(filepath) as f:
    content = f.read()

# 1. Add XmlPullParser import after LoggerFactory
marker = 'import org.slf4j.LoggerFactory;\n'
if marker not in content:
    print("ERROR: marker 'import org.slf4j.LoggerFactory' not found", file=sys.stderr)
    sys.exit(1)
if 'import org.xmlpull.v1.XmlPullParser;' not in content:
    content = content.replace(marker,
        marker + 'import org.xmlpull.v1.XmlPullParser;\n', 1)

# 2. Insert new method before the final closing brace of the class
new_method = '''
    /**
     * SBRW PATCH: Returns SASL mechanisms based on the XMPP stream opener's
     * 'from' attribute.  SASL is only offered when 'from' contains ".engine.engine"
     * (i.e. the soapbox-race-core server using Smack).  NFS World game clients do
     * not include ".engine.engine" so they receive null here, skip SASL entirely,
     * and authenticate immediately via IQ auth (jabber:iq:auth) without the
     * 2-minute SASL negotiation timeout.
     */
    public static Element getSASLMechanisms( LocalSession session, XmlPullParser xpp )
    {
        final String from = xpp.getAttributeValue( "", "from" );
        if ( session instanceof ClientSession )
        {
            if ( from != null && from.contains( ".engine.engine" ) )
            {
                // Engine (core server) connection - offer SASL as normal
                return getSASLMechanismsElement( (ClientSession) session );
            }
            // Game client connection - suppress SASL to avoid 2-minute timeout
            return null;
        }
        else if ( session instanceof LocalIncomingServerSession )
        {
            return getSASLMechanismsElement( (LocalIncomingServerSession) session );
        }
        else
        {
            Log.debug( "Unable to determine SASL mechanisms that are applicable to session \\'{}\\'. Unrecognized session type.", session );
            return null;
        }
    }
'''

last_brace = content.rfind('}')
if last_brace == -1:
    print("ERROR: could not find closing brace of class", file=sys.stderr)
    sys.exit(1)
content = content[:last_brace] + new_method + content[last_brace:]

with open(filepath, 'w') as f:
    f.write(content)
print("    SASLAuthentication.java patched OK")
PYEOF

# Patch LocalClientSession.java: change the one call site to pass xpp
echo "  Patching LocalClientSession.java..."
sed -i 's/SASLAuthentication\.getSASLMechanisms(session);/SASLAuthentication.getSASLMechanisms(session, xpp);/' \
  "$PATCH_DIR/src/org/jivesoftware/openfire/session/LocalClientSession.java"
# Verify the replacement was made
grep -q "getSASLMechanisms(session, xpp)" \
  "$PATCH_DIR/src/org/jivesoftware/openfire/session/LocalClientSession.java" \
  || { echo "ERROR: LocalClientSession.java patch failed (pattern not found)"; exit 1; }
echo "    LocalClientSession.java patched OK"

# Compile patched source files against Openfire's own classpath
echo "  Compiling patched classes (Java 11)..."
COMPILE_OUT=$("$JAVA11_BIN/javac" \
  -cp "$OF_CP" \
  -source 11 -target 11 \
  -d "$PATCH_DIR/classes" \
  "$PATCH_DIR/src/org/jivesoftware/openfire/net/SASLAuthentication.java" \
  "$PATCH_DIR/src/org/jivesoftware/openfire/session/LocalClientSession.java" \
  2>&1) || { echo "ERROR: Compilation failed:"; echo "$COMPILE_OUT"; exit 1; }
[[ -n "$COMPILE_OUT" ]] && echo "$COMPILE_OUT"
echo "    Compilation OK"

# Inject all generated class files back into xmppserver-4.9.2.jar
# (find handles '$' in SASLAuthentication inner class names safely via xargs)
echo "  Injecting patched classes into xmppserver-4.9.2.jar..."
cd "$PATCH_DIR/classes"
find . \( -name "SASLAuthentication*.class" -o -name "LocalClientSession*.class" \) \
  -print0 | xargs -0 "$JAVA11_BIN/jar" -uf "$OF_JAR"
echo "  SBRW SASL patch applied => $OF_JAR"

rm -rf "$PATCH_DIR"

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
