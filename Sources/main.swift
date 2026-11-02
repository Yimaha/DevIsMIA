import AppKit

let instanceLock = open(FileManager.default.temporaryDirectory.appendingPathComponent("local.presencelock.lock").path, O_CREAT | O_RDWR, 0o600)
if flock(instanceLock, LOCK_EX | LOCK_NB) != 0 {
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
