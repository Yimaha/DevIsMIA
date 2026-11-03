PresenceLock locks your Mac when nobody is in front of the camera for 10-60 seconds (default 20).
Requires macOS 14 or later.

INSTALL
1. Unzip PresenceLock.zip.
2. Open Terminal, type "bash " (with a space), drag install.sh from the
   PresenceLock folder into the Terminal window, and press Return.
3. Click Allow when macOS asks for camera access.

USE
Eye icon at the top right of the menu bar.
  Left-click   turn watching on / off (off = camera off)
  Right-click  settings (lock delay 10-60 seconds, Wi-Fi defaults) and Quit
It starts automatically at login.

WI-FI DEFAULTS (optional)
Right-click > "On here" / "Off here" saves the current Wi-Fi. PresenceLock then
switches on or off whenever you join it; left-click still overrides. Unsaved
networks change nothing. Remove saved networks under "Saved Wi-Fi".
Reading the Wi-Fi name needs a one-time Location permission (location is never used).

UNINSTALL (paste into Terminal)
launchctl bootout gui/$(id -u)/local.presencelock; rm ~/Library/LaunchAgents/local.presencelock.plist; rm -rf ~/Applications/PresenceLock.app
