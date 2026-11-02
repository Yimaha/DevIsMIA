import CoreGraphics
import Foundation

enum ScreenLocker {
    private typealias LockScreenImmediate = @convention(c) () -> Void

    static func lock() {
        guard let login = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY),
              let symbol = dlsym(login, "SACLockScreenImmediate") else { return }
        unsafeBitCast(symbol, to: LockScreenImmediate.self)()
    }

    static func isScreenLocked() -> Bool {
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        return session?["CGSSessionScreenIsLocked"] as? Bool ?? false
    }
}
