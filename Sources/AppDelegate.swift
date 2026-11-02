import AppKit
import AVFoundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let delayLabel = NSTextField(labelWithString: "")
    private let detector = PresenceDetector()
    private var watching = false
    private var screenLocked = ScreenLocker.isScreenLocked()
    private var asleep = false
    private var lastFrameAt = Date.distantPast
    private var absentSince: Date?

    private var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "enabled") }
    }

    private var lockDelay: TimeInterval {
        get { UserDefaults.standard.object(forKey: "lockDelay") as? TimeInterval ?? 20 }
        set { UserDefaults.standard.set(newValue, forKey: "lockDelay") }
    }

    private lazy var menu: NSMenu = {
        let slider = NSSlider(value: lockDelay, minValue: 10, maxValue: 60, target: self, action: #selector(lockDelayChanged(_:)))
        slider.numberOfTickMarks = 11
        slider.allowsTickMarkValuesOnly = true
        slider.frame = NSRect(x: 18, y: 6, width: 204, height: 24)
        delayLabel.frame = NSRect(x: 20, y: 30, width: 200, height: 18)
        showLockDelay()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 54))
        view.addSubview(delayLabel)
        view.addSubview(slider)
        let sliderItem = NSMenuItem()
        sliderItem.view = view

        let menu = NSMenu()
        menu.addItem(sliderItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }()

    private var cameraAllowed: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    private var shouldWatch: Bool {
        enabled && cameraAllowed && !screenLocked && !asleep
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        detector.onFrame = { [weak self] personPresent in self?.handleFrame(personPresent: personPresent) }

        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(self, selector: #selector(screenDidLock), name: .init("com.apple.screenIsLocked"), object: nil)
        distributed.addObserver(self, selector: #selector(screenDidUnlock), name: .init("com.apple.screenIsUnlocked"), object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(systemWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)

        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.checkCamera() }

        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { _ in
                DispatchQueue.main.async { self.update() }
            }
        }
        update()
    }

    private func update() {
        watching = shouldWatch
        if watching {
            absentSince = nil
            lastFrameAt = Date()
            detector.start()
        } else {
            detector.stop()
        }
        let symbol = !enabled ? "eye.slash" : cameraAllowed ? "eye" : "eye.trianglebadge.exclamationmark"
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "PresenceLock")
    }

    private func checkCamera() {
        if shouldWatch != watching {
            update()
        } else if watching && Date().timeIntervalSince(lastFrameAt) > 5 {
            detector.start()
        }
    }

    private func handleFrame(personPresent: Bool) {
        guard watching else { return }
        let now = Date()
        let resumedAfterGap = now.timeIntervalSince(lastFrameAt) > 3
        lastFrameAt = now
        if personPresent {
            absentSince = nil
            return
        }
        if absentSince == nil || resumedAfterGap {
            absentSince = now
        }
        if let since = absentSince, now.timeIntervalSince(since) >= lockDelay {
            absentSince = nil
            ScreenLocker.lock()
        }
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            enabled.toggle()
            update()
        }
    }

    @objc private func lockDelayChanged(_ slider: NSSlider) {
        lockDelay = slider.doubleValue.rounded()
        showLockDelay()
    }

    private func showLockDelay() {
        delayLabel.stringValue = "Lock after \(Int(lockDelay)) seconds away"
    }

    @objc private func screenDidLock() {
        screenLocked = true
        update()
    }

    @objc private func screenDidUnlock() {
        screenLocked = false
        update()
    }

    @objc private func systemWillSleep() {
        asleep = true
        update()
    }

    @objc private func systemDidWake() {
        asleep = false
        update()
    }
}
