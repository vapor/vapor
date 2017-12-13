import Foundation
import Debugging
import Security

/// An SSL Error related to Apple's Security libraries
public struct AppleTLSError: Swift.Error, Debuggable {
    public var reason: String
    public var identifier: String
    
    /// Creates a new error
    init(identifier: String, reason: String) {
        self.identifier = identifier
        self.reason = reason
    }

    public static func secError(_ status: OSStatus) -> AppleTLSError {
        let reason = SecCopyErrorMessageString(status, nil).flatMap { String($0) } ?? "An error occurred when setting up the TLS connection"
        return AppleTLSError(identifier: status.description, reason: reason)
    }
}
