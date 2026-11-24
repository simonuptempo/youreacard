#!/bin/bash
# Local stand-in for Supabase + the real war-and-piece function, scripted player B,
# and the Godot client as player A. Run from anywhere. GODOT = your Godot binary.
GODOT=${GODOT:-godot}
cd "$(dirname "$0")"
rm -f /tmp/wp_code.txt
node --experimental-strip-types --no-warnings run_server.ts > /tmp/wp_server.log 2>&1 &
SRV=$!
sleep 1.5
node --experimental-strip-types --no-warnings player_b.ts > /tmp/wp_b.log 2>&1 &
B=$!
cd ../../../..   # the You're a Card project folder
YAC_SERVER=http://127.0.0.1:54321 timeout 300 ${GODOT_RUN:-$GODOT --headless} --path . -s res://games/war_and_piece/tests/online_e2e.gd 2>&1 | grep -E "^A |E2E|SCRIPT|ERROR: [^NGC]" | grep -v gdextension | head -40
sleep 2
kill $B $SRV 2>/dev/null
echo "--- player B"; tail -4 /tmp/wp_b.log
echo "--- server errors"; grep -iE "error|exception" /tmp/wp_server.log | head -10
