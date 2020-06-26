extension Logger {
    /// Reports an `Error` to this `Logger`.
    ///
    /// - parameters:
    ///     - error: `Error` to log.
    public func report(
        error: Error,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        let source: ErrorSource?
        let reason: String
        let level: Logger.Level
        switch error {
        case let debuggable as DebuggableError:
            if self.logLevel <= .trace {
                reason = debuggable.debuggableHelp(format: .long)
            } else {
                reason = debuggable.debuggableHelp(format: .short)
            }
            source = debuggable.source
            level = debuggable.logLevel
        case let abort as AbortError:
            reason = abort.reason
            source = nil
            level = .error
        case let localized as LocalizedError:
            reason = localized.localizedDescription
            source = nil
            level = .error
        case let convertible as CustomStringConvertible:
            reason = convertible.description
            source = nil
            level = .error
        default:
            reason = "\(error)"
            source = nil
            level = .error
        }
        self.log(
            level: level,
            .init(stringLiteral: reason),
            file: source?.file ?? file,
            function: source?.function ?? function,
            line: numericCast(source?.line ?? line)
        )
    }
}

struct MyError: DebuggableError {
    enum Value {
        case userNotLoggedIn
        case invalidEmail(String)
    }

    var identifier: String {
        switch self.value {
        case .userNotLoggedIn:
            return "userNotLoggedIn"
        case .invalidEmail:
            return "invalidEmail"
        }
    }

    var reason: String {
        switch self.value {
        case .userNotLoggedIn:
            return "User is not logged in."
        case .invalidEmail(let email):
            return "Email address is not valid: \(email)."
        }
    }

    var value: Value
    var source: ErrorSource?
    var stackTrace: StackTrace?

    init(
        _ value: Value,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column,
        stackTrace: StackTrace? = .capture()
    ) {
        self.value = value
        self.source = .init(
            file: file,
            function: function,
            line: line,
            column: column
        )
        self.stackTrace = stackTrace
    }
}
