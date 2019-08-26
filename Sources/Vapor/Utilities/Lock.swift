public struct Lock {
    private let nslock: NSLock
    init() {
        self.nslock = .init()
    }

    public func lock() {
        self.nslock.lock()
    }

    public func unlock() {
        self.nslock.unlock()
    }

    public func `do`(_ closure: () throws -> Void) rethrows {
        self.lock()
        defer { self.unlock() }
        try closure()
    }
}
