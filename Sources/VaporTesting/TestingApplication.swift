import AsyncHTTPClient
public import Vapor
import NIOPosix
import NIOCore
import NIOFoundationEssentialsCompat
import NIOHTTPTypesHTTP1
import Logging
import NIOHTTP1
import HTTPTypes
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


extension ResponseBodyCollection {
    /// Resolves a response body according to this policy.
    ///
    /// `.collect` reads it up front, so the body handed to a test is an ordinary in-memory one and
    /// the request completes rather than being cancelled when nothing reads it. `.stream` hands it
    /// over untouched.
    func apply(to body: Response.Body) async throws -> Response.Body {
        switch self {
        case .stream:
            return body
        case .collect(let max):
            var body = body
            return .init(data: try await body.collect(max: max) ?? Data())
        }
    }
}
