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
- **Right-click**: settings (lock delay, 10–60 seconds) and Quit

## Uninstall

```sh
launchctl bootout gui/$(id -u)/local.presencelock; rm ~/Library/LaunchAgents/local.presencelock.plist; rm -rf ~/Applications/PresenceLock.app
```
