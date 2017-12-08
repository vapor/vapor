import Foundation
import Debugging
import Security

/// An SSL Error related to Apple's Security libraries
public struct AppleSSLError: Swift.Error, Debuggable {
    public var reason: String {
        return "An error occurred when setting up the SSL connection"
    }
    
    public var identifier: String {
        return "\(reason)"
    }
    
    let problem: Problem
    
    /// Creates a new error
    init(_ problem: Problem) {
        self.problem = problem
    }
    
    /// These reasons are internal so they cannot be caught publically.
    ///
    /// This allows adding extra error reasons
    enum Problem {
        /// Creating the SSL context failed
        case cannotCreateContext
        
        /// The context was already created. Will not reinitialize
        case contextAlreadyCreated
        
        /// SSL was not initialized. This operation requires a context
        case noSSLContext
        
        /// An SSL internal error occurred
        case sslError(Int32)
        
        /// The provided certificate was not loaded/used successfully
        case invalidCertificate
        
        /// Unsupported feature
        case notSupported
        
        /// The certificate didn't exist at the given path
        case certificateNotFound
    }
}
