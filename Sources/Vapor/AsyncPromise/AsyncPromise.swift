
import Foundation

public enum Result<T> {
    case success(T)
    case failure(ErrorProtocol)

    public func extract() throws -> T {
        switch self {
        case .success(let val):
            return val
        case .failure(let e):
            throw e
        }
    }
}

public enum PromiseError: ErrorProtocol {
    case promiseNotCalled
    case timedOut
}

// TODO: Is Promise the right word here?

public final class Promise<T> {
    private var result: Result<T>? = .none
    private let semaphore: DispatchSemaphore

    private init(_ semaphore: DispatchSemaphore) {
        self.semaphore = semaphore
    }

    public func send(_ value: T) {
        // TODO: Fatal error or throw? It's REALLY convenient NOT to throw here. Should at least log warning
        guard result == nil else { return }
        result = .success(value)
        semaphore.signal()
    }

    public func send(_ error: ErrorProtocol) {
        guard result == nil else { return }
        result = .failure(error)
        semaphore.signal()
    }
}

extension Promise {
    public static func async(timingOut timeout: DispatchTime = .distantFuture,
                             with handler: (Promise) throws -> Void) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        let sender = Promise<T>(semaphore)
        // Ok to call synchronously, since will still unblock semaphore
        // TODO: Find a way to enforce sender is called, not calling will perpetually block w/ long timeout
        try handler(sender)
        // TODO: Expose timeout customization -- I think Foundation is missing initializer
        let semaphoreResult = semaphore.wait(timeout: timeout)
        switch semaphoreResult {
        case .Success:
            guard let result = sender.result else { throw PromiseError.promiseNotCalled }
            return try result.extract()
        case .TimedOut:
            throw PromiseError.timedOut
        }
    }
}

public protocol Empty {}
extension HTTPResponse: Empty {}

extension Empty where Self: HTTPResponse {
    public init(async: (Promise<Self>) throws -> Void) throws {
        self = try Promise.async(with: async)
    }
}
