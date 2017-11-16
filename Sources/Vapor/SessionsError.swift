import Debugging
import Foundation
import libc

/// Errors that can be thrown while working with Vapor Sessions Cookies.
public struct SessionsError: Traceable, Helpable, Debuggable, Swift.Error, Encodable {
    public var possibleCauses: [String] {
        return [
            "The `SessionCookieMiddleware` was not added to the chain for this route.",
            "The `SessionCookieMiddleware` has deserialized a type other than the requested type \"\(typeName)\""
        ]
    }
    
    public var suggestedFixes: [String] {
        return [
            "Add the `SessionCookieMiddleware<\(typeName)>` to a group for this route or to the application's service."
        ]
    }
    
    public static let readableName = "Sessions Error"
    public let identifier: String
    public var reason: String
    public var file: String
    public var function: String
    public var line: UInt
    public var column: UInt
    public var stackTrace: [String]
    
    private let typeName: String
    
    private init(
        identifier: String,
        reason: String,
        typeName: String,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        self.identifier = identifier
        self.reason = reason
        self.typeName = typeName
        self.file = file
        self.function = function
        self.line = line
        self.column = column
        self.stackTrace = SessionsError.makeStackTrace()
    }
    
    static func cookieNotFound<T>(
        name: String?,
        type: T.Type,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) -> SessionsError {
        if let name = name {
            return SessionsError(
                identifier: "cookie-not-found",
                reason: "Unable to find a cookie named \"\(name)\" with the type \"\(T.self)\" in the request",
                typeName: "\(T.self)",
                file: file,
                function: function,
                line: line,
                column: column
            )
        } else {
            return SessionsError(
                identifier: "cookie-not-found",
                reason: "No session cookies with the type \"\(T.self)\" were found in the request.",
                typeName: "\(T.self)",
                file: file,
                function: function,
                line: line,
                column: column
            )
        }
    }
}

