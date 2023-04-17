import Foundation
import NIOConcurrencyHelpers

@propertyWrapper
class ThreadSafe<Value> {
    private var value: Value
    private let lock = NIOLock()
    
    public init(wrappedValue value: Value) {
        self.value = value
    }
    
    public var wrappedValue: Value {
        get { return lock.withLock { return value } }
        set { lock.withLockVoid { value = newValue } }
    }
}
