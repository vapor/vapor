import Debugging

/// Drivers that can perform data transactions should
/// conform to this protocol.
public protocol Transactable {
    func transaction<R>(_ closure: (Connection) throws -> R) throws -> R
}

extension Database: Transactable {
    /// Transactions allow you to group multiple queries
    /// into one single unit of work. If any one of the 
    /// queries experiences a problem, the entire transaction will
    /// be rolled back.
    ///
    /// note: the underlying driver must support transactions
    public func transaction<R>(_ closure: (Connection) throws -> R) throws -> R {
        guard let t = driver as? Transactable else {
            throw TransactionError.unsupported(type(of: driver))
        }
        
        return try t.transaction(closure)
    }
}

public enum TransactionError: Error {
    case unsupported(Driver.Type)
    case unspecified(Error)
}

extension TransactionError: Debuggable {
    public var reason: String {
        switch self {
        case .unsupported(let driver):
            return "Driver type \(driver) does not supported transactions."
        case .unspecified(let error):
            return "\(error)"
        }
    }
    
    public var identifier: String {
        switch self {
        case .unsupported:
            return "unsupported"
        case .unspecified:
            return "unspecified"
        }
    }
    
    public var possibleCauses: [String] {
        return []
    }
    
    public var suggestedFixes: [String] {
        return [
            "Ask the creator of this driver to add transaction support"
        ]
    }
}
