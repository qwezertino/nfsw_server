#!/bin/bash
# Build script — runs inside the builder Docker container.
# Builds all artifacts and places them in sbrw/ for the runtime containers.
set -e

REPOS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELFDIR="$REPOS/sbrw"

step() { echo ""; echo ">>> $*"; }

# ── Output directories ────────────────────────────────────────────────────────
step "Creating output directories..."
mkdir -p "$SELFDIR/core"
mkdir -p "$SELFDIR/freeroam"
mkdir -p "$SELFDIR/race"
mkdir -p "$SELFDIR/openfire/plugins"
mkdir -p "$SELFDIR/modnet"

# ── soapbox-race-core (Thorntail / Java) ──────────────────────────────────────
step "Building SBRW-Core (Maven)..."
cd "$REPOS/src/soapbox-race-core"
mvn clean package -q -DskipTests
cp -f "target/core-thorntail.jar" "$SELFDIR/core/core.jar"
# project-defaults.yml is generated at runtime by docker/core-entrypoint.sh
echo "  => $SELFDIR/core/core.jar"

# ── Freeroam (Go) ─────────────────────────────────────────────────────────────
step "Building Freeroam server (Go)..."
cd "$REPOS/src/freeroam/cmd/freeroamd"
go build -o freeroamd freeroamd.go
cp -f freeroamd "$SELFDIR/freeroam/freeroamd"
chmod +x "$SELFDIR/freeroam/freeroamd"
echo "  => $SELFDIR/freeroam/freeroamd"

# ── Race server (pre-built JAR) ───────────────────────────────────────────────
step "Copying Race server..."
cp -f "$REPOS/src/sbrw-mp-sync-2018/sbrw-mp.jar" "$SELFDIR/race/race.jar"
mkdir -p "$SELFDIR/race/keys"
echo "  => $SELFDIR/race/race.jar"
echo "  => $SELFDIR/race/keys/"

# ── Openfire fork (4.5.0-SNAPSHOT) ───────────────────────────────────────────
step "Building SBRW Openfire fork (4.5.0-SNAPSHOT)..."
cd "$REPOS/src/openfire"
JAVA_HOME="${JAVA8_HOME:-${JAVA_HOME}}" mvn install -pl xmppserver -am -DskipTests -q
JAVA_HOME="${JAVA8_HOME:-${JAVA_HOME}}" mvn package -pl distribution -am -DskipTests -q

rm -rf "$SELFDIR/openfire"
mkdir -p "$SELFDIR/openfire/plugins"
cp -r "$REPOS/src/openfire/distribution/target/distribution-base/." "$SELFDIR/openfire/"
chmod +x "$SELFDIR/openfire/bin/openfire.sh"
echo "  => $SELFDIR/openfire/"

# ── Openfire plugins ──────────────────────────────────────────────────────────
step "Downloading Openfire plugins..."
curl -sSL -o "$SELFDIR/openfire/plugins/restAPI.jar" \
    "https://www.igniterealtime.org/projects/openfire/plugins/1.4.0/restAPI.jar"
curl -sSL -o "$SELFDIR/openfire/plugins/nonSaslAuthentication.jar" \
    "https://www.igniterealtime.org/projects/openfire/plugins/1.0.1/nonSaslAuthentication.jar"
echo "  => restAPI.jar, nonSaslAuthentication.jar"

# ── ModNet static index ───────────────────────────────────────────────────────
step "Creating ModNet index..."
cat > "$SELFDIR/modnet/index.json" <<'JSON'
{
    "built_at": "2021-02-28T23:01:24.394847+03:00",
    "entries": []
}
JSON
echo "  => $SELFDIR/modnet/index.json"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo "  Build complete! Artifacts in: $SELFDIR"
echo "============================================================"
