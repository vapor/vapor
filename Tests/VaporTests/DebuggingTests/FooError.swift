import Vapor

enum FooError: String, Error {
    case noFoo
}

extension FooError: Debuggable {
    static var readableName: String {
        return "Foo Error"
    }

    var identifier: String {
        return rawValue
    }

    var reason: String {
        switch self {
            case .noFoo:
                return "You do not have a `foo`."
        }
    }

    var possibleCauses: [String] {
        switch self {
            case .noFoo:
                return [
                    "You did not set the flongwaffle.",
                    "The session ended before a `Foo` could be made.",
                    "The universe conspires against us all.",
                    "Computers are hard."
            ]
        }
    }

    var suggestedFixes: [String] {
        switch self {
            case .noFoo:
                return [
                    "You really want to use a `Bar` here.",
                    "Take up the guitar and move to the beach."
            ]
        }
    }

    var documentationLinks: [String] {
        switch self {
            case .noFoo:
                return [
                    "http://documentation.com/Foo",
                    "http://documentation.com/foo/noFoo"
            ]
        }
    }

}
