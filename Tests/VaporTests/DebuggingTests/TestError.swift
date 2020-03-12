import Vapor

struct TestError: Error {
    enum Kind: String {
        case foo
        case bar
        case baz
    }

    var kind: Kind
    var reason: String
    var file: String
    var function: String
    var line: UInt
    var column: UInt
    var stackTrace: [String]

    init(kind: Kind, reason: String, file: String = #file, function: String = #function, line: UInt = #line, column: UInt = #column) {
        self.kind = kind
        self.reason = reason
        self.file = file
        self.function = function
        self.line = line
        self.column = column
        self.stackTrace = TestError.makeStackTrace()
    }

    static func foo(reason: String, file: String = #file, function: String = #function, line: UInt = #line, column: UInt = #column) -> TestError {
        return TestError(kind: .foo, reason: reason, file: file, function: function, line: line, column: column)
    }
}

extension TestError: Debuggable {
    var identifier: String {
        return kind.rawValue
    }

    var possibleCauses: [String] {
        switch kind {
            case .foo:
                return ["What do you expect, you're testing errors."]
            default:
                return []
        }
    }

    var suggestedFixes: [String] {
        switch kind {
            case .foo:
                return ["Get a better keyboard to chair interface."]
            default:
                return []
        }
    }


}
