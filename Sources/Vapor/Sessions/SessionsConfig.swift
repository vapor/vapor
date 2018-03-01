//import Foundation
//
///// Configuration options for sessions.
//public struct SessionsConfig {
//    /// Generates a new cookie.
//    /// Accepts the cookie's string value and returns an
//    /// initialized cookie value.
//    public typealias CookieFactory = (String) -> (Cookie.Value)
//
//    /// Creates cookie values.
//    public let cookieFactory: CookieFactory
//
//    /// The session cookie's name
//    public let cookieName: String
//
//    /// Create a new `SessionsConfig` with the supplied cookie factory.
//    public init(cookieName: String, cookieFactory: @escaping CookieFactory) {
//        self.cookieName = cookieName
//        self.cookieFactory = cookieFactory
//    }
//
//    /// `SessionsConfig` with basic cookie factory.
//    public static func `default`() -> SessionsConfig {
//        return .init(cookieName: "vapor-sessions") { value in
//            return Cookie.Value(
//                value: value,
//                expires: Date(
//                    timeIntervalSinceNow: 60 * 60 * 24 * 7 // one week
//                ),
//                maxAge: nil,
//                domain: nil,
//                path: "/",
//                secure: false,
//                httpOnly: false,
//                sameSite: nil
//            )
//        }
//    }
//}
//
//extension SessionsConfig: ServiceType {
//    /// See `ServiceType.makeService(for:)`
//    public static func makeService(for worker: Container) throws -> SessionsConfig {
//        return .default()
//    }
//}

