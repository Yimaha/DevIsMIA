# DevIsMIA

Locks your Mac when nobody is in front of the camera for 10–60 seconds (default 20).

Requires macOS 14+ and Xcode Command Line Tools.

## Install

```sh
git clone https://github.com/Yimaha/DevIsMIA.git && cd DevIsMIA && ./package.sh && dist/PresenceLock/install.sh
```

Click **Allow** when asked for camera access.

## Use

Eye icon in the menu bar (top right):

- **Left-click**: turn watching on/off
- **Right-click**: settings (lock delay 10–60 seconds, Wi-Fi defaults) and Quit

**Wi-Fi defaults (optional):** right-click → **On here** / **Off here** to save the current Wi-Fi. PresenceLock then switches on or off whenever you join it; left-click still overrides. Unsaved networks change nothing. Remove saved networks under **Saved Wi-Fi**. Reading the Wi-Fi name needs a one-time Location permission (your location is never used).

## Uninstall

```sh
launchctl bootout gui/$(id -u)/local.presencelock; rm ~/Library/LaunchAgents/local.presencelock.plist; rm -rf ~/Applications/PresenceLock.app
```
