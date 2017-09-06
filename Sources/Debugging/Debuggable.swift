/// `Debuggable` provides an interface that allows a type
/// to be more easily debugged in the case of an error.
public protocol Debuggable: CustomDebugStringConvertible, CustomStringConvertible, Identifiable {}

// MARK: Defaults

extension Debuggable {
    public var debugDescription: String {
        return debuggableHelp(format: .long)
    }

    public var description: String {
        return debuggableHelp(format: .short)
    }
}

extension Debuggable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.reason)
    }
}

// MARK: Representations

extension Debuggable {
    /// A computed property returning a `String` that encapsulates
    /// why the error occurred, suggestions on how to fix the problem,
    /// and resources to consult in debugging (if these are available).
    /// - note: This representation is best used with functions like print()
    public func debuggableHelp(format: HelpFormat) -> String {
        var print: [String] = []

        print.append(identifiableHelp(format: format))

        if let traceable = self as? Traceable {
            print.append(traceable.traceableHelp(format: format))
        }

        if let helpable = self as? Helpable {
            print.append(helpable.helpableHelp(format: format))
        }

        if let traceable = self as? Traceable, format == .long {
            let lines = ["Stack Trace:"] + traceable.stackTrace
            print.append(lines.joined(separator: "\n"))
        }


        switch format {
        case .long:
            return print.joined(separator: "\n\n")
        case .short:
            return print.joined(separator: " ")
        }
    }
}
