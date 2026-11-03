#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

LABEL="local.presencelock"
APP="$HOME/Applications/PresenceLock.app"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"

echo "==> [1/3] Stopping any running PresenceLock..."
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -x PresenceLock || true
echo "==> [2/3] Copying PresenceLock to ~/Applications..."
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"
ditto PresenceLock.app "$APP"
xattr -cr "$APP"

cat > "$AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP/Contents/MacOS/PresenceLock</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>LimitLoadToSessionType</key>
    <string>Aqua</string>
</dict>
</plist>
EOF

echo "==> [3/3] Starting PresenceLock..."
launchctl bootstrap "gui/$(id -u)" "$AGENT"
echo "Done. Click Allow when asked for camera access."
