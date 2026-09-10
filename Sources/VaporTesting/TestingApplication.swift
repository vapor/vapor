public import Vapor
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension Application {
    public enum Method {
        /// Default option without a socket. Calls the responder directly
        case inMemory
        /// Runs a real server and binds to the specified port and address
        case running
    }
}

package enum TestErrors: Error {
    case portNotSet
    case missingPort
    case missingHostname
}
