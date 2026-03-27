#!/bin/bash
# ============================================================
#  SBRW Linux Start Script
#  Equivalent of start-sbrw.bat, adapted for Linux/WSL
#
#  Requires: tmux  (sudo apt install tmux)
#  Uses a named tmux session with a window per component.
#
#  Reattach any time:
#    tmux attach -t sbrw
#  Switch windows inside tmux:
#    Ctrl+b, then 0=openfire  1=freeroam  2=race  3=core
#  Detach without killing: Ctrl+b, then d
#  Stop everything:
#    bash start.sh --stop
# ============================================================

SELFDIR="/home/qwezert/nfsw_server/sbrw"
SESSION="sbrw"
SERVER_PORT="4444"
LOGDIR="$SELFDIR/logs"

# -------------------------------------------------------
# --stop: kill the tmux session
# -------------------------------------------------------
if [[ "${1}" == "--stop" ]]; then
    tmux kill-session -t "$SESSION" 2>/dev/null && echo "Session '$SESSION' stopped." || echo "Session '$SESSION' not found."
    exit 0
fi

# Verify the build output exists
if [[ ! -f "$SELFDIR/core/core.jar" ]]; then
    echo "ERROR: $SELFDIR/core/core.jar not found."
    echo "Run build.sh first."
    exit 1
fi

# Kill existing session if it exists
tmux kill-session -t "$SESSION" 2>/dev/null || true

mkdir -p "$LOGDIR"

echo "Starting SBRW server components in tmux session '$SESSION'..."
echo ""

# Window 0 – Openfire (needs Java 11 explicitly, openfire.sh auto-detects wrong version)
# TLSv1/TLSv1.1 are re-enabled via /usr/lib/jvm/java-11-openjdk-amd64/conf/security/java.security
# OPENFIRE_OPTS: disable OCSP/CRL cert revocation checks (causes ~2 minute TLS delay for game client)
tmux new-session -d -s "$SESSION" -n "openfire" \
    "cd '$SELFDIR/openfire' && JAVA_HOME=/usr/lib/jvm/java-1.11.0-openjdk-amd64 OPENFIRE_OPTS='-Dcom.sun.security.enableCRLDP=false -Dcom.sun.security.ocsp.enable=false' bash bin/openfire.sh 2>&1 | tee '$LOGDIR/openfire.log'; exec bash"
echo "  [OK] Openfire   -> window 0  | log: $LOGDIR/openfire.log"

sleep 2

# Window 1 – Freeroam UDP server
tmux new-window -t "$SESSION" -n "freeroam" \
    "cd '$SELFDIR/freeroam' && ./freeroamd 2>&1 | tee '$LOGDIR/freeroam.log'; exec bash"
echo "  [OK] Freeroam   -> window 1  | log: $LOGDIR/freeroam.log"

# Window 2 – Race (sbrw-mp) server
tmux new-window -t "$SESSION" -n "race" \
    "cd '$SELFDIR/race' && java -jar race.jar 9998 2>&1 | tee '$LOGDIR/race.log'; exec bash"
echo "  [OK] Race       -> window 2  | log: $LOGDIR/race.log"

# Window 3 – Soapbox Core (Thorntail)
tmux new-window -t "$SESSION" -n "core" \
    "cd '$SELFDIR/core' && java -Dthorntail.http.port=$SERVER_PORT -jar core.jar 2>&1 | tee '$LOGDIR/core.log'; exec bash"
echo "  [OK] Core       -> window 3  | log: $LOGDIR/core.log"

# Window 4 – ModNet static HTTP server (serves index.json for powerups/events)
tmux new-window -t "$SESSION" -n "modnet" \
    "cd '$SELFDIR/modnet' && python3 -m http.server 8000 2>&1 | tee '$LOGDIR/modnet.log'; exec bash"
echo "  [OK] ModNet     -> window 4  | log: $LOGDIR/modnet.log"

echo ""
echo "All components launched. Useful commands:"
echo ""
echo "  Attach to session:   tmux attach -t $SESSION"
echo "  Switch windows:      Ctrl+b, then window number (0-3)"
echo "  Detach (keep alive): Ctrl+b, then d"
echo "  List sessions:       tmux ls"
echo "  Stop everything:     bash $0 --stop"
echo ""
echo "Once Thorntail prints 'Thorntail is Ready', the core server is up."
echo "Core server URL: http://localhost:$SERVER_PORT"
echo "Openfire admin:  http://localhost:9090"
