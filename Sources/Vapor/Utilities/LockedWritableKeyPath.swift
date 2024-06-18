import Foundation

final class LockedWritableKeyPath<Root, Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var path: WritableKeyPath<Root, Value>

    init(path: WritableKeyPath<Root, Value>) {
        self.path = path
    }

    var safeValue: WritableKeyPath<Root, Value>? {
        get {
            var lockedValue: WritableKeyPath<Root, Value>?
            lock.lock()
            lockedValue = path
            lock.unlock()

            return lockedValue
        }
    }
}
