import Foundation

@propertyWrapper
class ThreadSafe<Value> {
    private var value: Value
    private let lock = Lock()
    
    public init(wrappedValue value: Value) {
        self.value = value
    }
    
    public var wrappedValue: Value {
        get { return lock.run { return value } }
        set { lock.run { value = newValue } }
    }
}

fileprivate class Lock {
    private let nslock = NSLock()
    init() {}
    
    func lock() {
        nslock.lock()
    }
    
    func unlock() {
        nslock.unlock()
    }
    
    func run(_ closure: () throws -> Void) rethrows {
        lock()
        try closure()
        unlock()
    }
    
    func run<T>(_ closure: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try closure()
    }
}
