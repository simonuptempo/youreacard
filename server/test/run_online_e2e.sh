#!/bin/bash
# Mock Supabase + real server function, scripted player B, Godot client as player A.
cd /home/claude/server/test
rm -f /tmp/yac_code.txt
node --experimental-strip-types --no-warnings run_server.ts > /tmp/yac_server.log 2>&1 &
SRV=$!
sleep 1.5
node --experimental-strip-types --no-warnings player_b.ts > /tmp/yac_b.log 2>&1 &
B=$!
cd /mnt/user-data/outputs/YoureACard
YAC_SERVER=http://127.0.0.1:54321 timeout 600 /tmp/godot/Godot_v4.7.1-stable_linux.x86_64 --headless --path . -s res://tests/online_e2e.gd 2>&1 | grep -E "^A |E2E|SCRIPT|ERROR: [^RC]" | head -40
sleep 3
kill $B $SRV 2>/dev/null
echo "--- player B"; cat /tmp/yac_b.log | tail -8
echo "--- server errors"; grep -iE "error|exception" /tmp/yac_server.log | head -10
