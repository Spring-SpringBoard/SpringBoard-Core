#!/bin/bash
# Local smoke test runner
# Run this script to test SpringBoard locally before pushing to CI

set -e

echo "=== SpringBoard Local Smoke Test ==="
echo ""

# Check if we're in the right directory
if [ ! -f "modinfo.lua" ]; then
    echo "Error: Run this script from SpringBoard-Core root directory"
    exit 1
fi

# Check dependencies
echo "Checking dependencies..."
command -v wget >/dev/null 2>&1 || { echo "Error: wget not installed"; exit 1; }
command -v 7z >/dev/null 2>&1 || { echo "Error: p7zip not installed"; exit 1; }
command -v xvfb-run >/dev/null 2>&1 || { echo "Error: xvfb not installed"; exit 1; }
echo "✓ Dependencies OK"
echo ""

# Download engine if not present
if [ ! -f "spring" ]; then
    echo "Downloading BAR Engine..."
    wget -q "https://github.com/beyond-all-reason/spring/releases/download/spring_bar_%7BBAR105%7D105.1.1-2472-ga5aa45c/spring_bar_.BAR105.105.1.1-2472-ga5aa45c_linux-64-minimal-portable.7z"
    7z x -y "spring_bar_.BAR105.105.1.1-2472-ga5aa45c_linux-64-minimal-portable.7z"
    rm *.7z
    chmod +x spring
    echo "✓ Engine downloaded"
else
    echo "✓ Engine already present"
fi
echo ""

# Setup game directory
echo "Setting up game directory..."
mkdir -p games
ln -sf "$(pwd)" "games/SpringBoard Core.sdd"
echo "✓ Game directory set up"
echo ""

# Create config to disable audio
echo "Creating Spring config..."
mkdir -p test-data
cat > test-data/springsettings.cfg << 'EOF'
snd_disable = 1
snd_volmaster = 0
EOF
echo "✓ Config created"
echo ""

# Create script.txt
echo "Creating Spring script..."
cat > script.txt << 'EOF'
[GAME]
{
  GameType=SpringBoard Core;
  MapName=generated_test_map;
  IsHost=1;
  MyPlayerName=TestPlayer;
  [MAPOPTIONS]
  {
    new_map_x=10;
    new_map_y=8;
  }
  [MODOPTIONS]
  {
    mapseed=1;
  }
  [PLAYER0]
  {
    Name=TestPlayer;
    Team=0;
    IsFromDemo=0;
    Spectator=1;
  }
  [TEAM0]
  {
    TeamLeader=0;
    AllyTeam=0;
  }
  [ALLYTEAM0]
  {
  }
}
EOF
echo "✓ Script created"
echo ""

# Run the test
echo "=== Running SpringBoard with Xvfb ==="
echo "This will run for 10 seconds..."
echo ""

timeout 10s xvfb-run -a -s "-screen 0 1024x768x24" \
  ./spring --write-dir $(pwd)/test-data script.txt || EXIT_CODE=$?

sleep 2

echo ""
echo "=== Test Results ==="
echo "Exit code: ${EXIT_CODE:-0}"
echo ""

# Validate results
if [ ! -f test-data/infolog.txt ]; then
    echo "✗ FAIL: No infolog.txt generated"
    exit 1
fi

if grep -q "CrashHandler.*Error.*Aborted\|XIO.*fatal.*error\|terminate called" test-data/infolog.txt; then
    echo "✗ FAIL: Spring crashed"
    echo ""
    tail -50 test-data/infolog.txt
    exit 1
fi

if ! grep -q "LuaUI.*Loaded\|Loading LuaUI" test-data/infolog.txt; then
    echo "✗ FAIL: LuaUI did not load"
    echo ""
    tail -50 test-data/infolog.txt
    exit 1
fi

echo "✓ LuaUI loaded"

if grep -q -i "rmlui" test-data/infolog.txt; then
    echo "✓ RmlUi found in logs"
    grep -i "rmlui" test-data/infolog.txt | head -5
else
    echo "⚠ Warning: No RmlUi messages"
fi

echo ""
echo "✓✓✓ SMOKE TEST PASSED ✓✓✓"
echo ""
echo "View full log: test-data/infolog.txt"
