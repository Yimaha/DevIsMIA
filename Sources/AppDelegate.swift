import AppKit
import AVFoundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let delayLabel = NSTextField(labelWithString: "")
    private let detector = PresenceDetector()
    private let wifi = WiFiDefaults()
    private let menu = NSMenu()
    private var lastNetwork: String?
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

    private lazy var sliderItem: NSMenuItem = {
        let slider = NSSlider(value: lockDelay, minValue: 10, maxValue: 60, target: self, action: #selector(lockDelayChanged(_:)))
        slider.numberOfTickMarks = 11
        slider.allowsTickMarkValuesOnly = true
        slider.frame = NSRect(x: 18, y: 6, width: 204, height: 24)
        delayLabel.frame = NSRect(x: 20, y: 30, width: 200, height: 18)
        showLockDelay()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 54))
        view.addSubview(delayLabel)
        view.addSubview(slider)
        let item = NSMenuItem()
        item.view = view
        return item
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

        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.checkCamera()
            self?.applyWiFiDefault()
        }

        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { _ in
                DispatchQueue.main.async { self.update() }
            }
        }
        update()
        applyWiFiDefault()
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
            rebuildMenu()
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            enabled.toggle()
            update()
        }
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        menu.addItem(sliderItem)
        menu.addItem(.separator())

        if let network = wifi.currentNetwork {
            let saved = wifi.saved[network]
            menu.addItem(withTitle: "Wi-Fi “\(network)”", action: nil, keyEquivalent: "")
            for (title, tag, isSet) in [("On here", 1, saved == true), ("Off here", 0, saved == false), ("No default", -1, saved == nil)] {
                let item = NSMenuItem(title: title, action: #selector(setWiFiDefault(_:)), keyEquivalent: "")
                item.target = self
                item.tag = tag
                item.state = isSet ? .on : .off
                menu.addItem(item)
            }
        } else if wifi.permissionDenied {
            menu.addItem(withTitle: "Wi-Fi defaults need Location access in System Settings", action: nil, keyEquivalent: "")
        } else if wifi.canReadNetworkName {
            menu.addItem(withTitle: "Not connected to Wi-Fi", action: nil, keyEquivalent: "")
        } else {
            let item = NSMenuItem(title: "Set a default for this Wi-Fi…", action: #selector(requestWiFiAccess), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }

        let saved = wifi.saved
        if !saved.isEmpty {
            let submenu = NSMenu()
            submenu.addItem(withTitle: "Click a network to remove it", action: nil, keyEquivalent: "")
            for (network, on) in saved.sorted(by: { $0.key < $1.key }) {
                let item = NSMenuItem(title: "\(network) — \(on ? "On" : "Off")", action: #selector(removeWiFiDefault(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = network
                submenu.addItem(item)
            }
            let savedItem = NSMenuItem(title: "Saved Wi-Fi", action: nil, keyEquivalent: "")
            savedItem.submenu = submenu
            menu.addItem(savedItem)
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    private func applyWiFiDefault() {
        guard !wifi.saved.isEmpty else { return }
        let network = wifi.currentNetwork
        guard network != lastNetwork else { return }
        lastNetwork = network
        if let network, let on = wifi.saved[network] {
            enabled = on
            update()
        }
    }

    @objc private func requestWiFiAccess() {
        wifi.requestPermission()
    }

    @objc private func setWiFiDefault(_ item: NSMenuItem) {
        guard let network = wifi.currentNetwork else { return }
        var saved = wifi.saved
        saved[network] = item.tag < 0 ? nil : item.tag == 1
        wifi.saved = saved
        lastNetwork = network
        if item.tag >= 0 {
            enabled = item.tag == 1
            update()
        }
    }

    @objc private func removeWiFiDefault(_ item: NSMenuItem) {
        guard let network = item.representedObject as? String else { return }
        var saved = wifi.saved
        saved[network] = nil
        wifi.saved = saved
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
