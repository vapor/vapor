/// An SSL Error related to Apple's Security libraries
public struct OpenSSLError: Swift.Error {
    /// The reason for this error
    let reason: Reason
    
    /// Creates a new error
    init(_ reason: Reason) {
        self.reason = reason
    }
    
    /// These reasons are internal so they cannot be caught publically.
    ///
    /// This allows adding extra error reasons
    enum Reason {
        /// OpenSSL was not initialized
        case notInitialized
        
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
        
        /// Unknown ALPN protocol selected
        case invalidALPNProtocol
    }
}
