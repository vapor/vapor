public enum PaginationError: Error {
    case invalidPageNumber(Int)
    case unspecified(Error)
}

import Debugging

extension PaginationError: Debuggable {
    public var reason: String {
        switch self {
        case .invalidPageNumber(let num):
            return "'\(num)' is not a valid page number."
        case .unspecified(let error):
            return "Unknown: \(error)"
        }
    }

    public var identifier: String {
        switch self {
        case .invalidPageNumber:
            return "invalidPageNumber"
        case .unspecified:
            return "unknown"
        }
    }

    public var possibleCauses: [String] {
        switch self {
        case .invalidPageNumber:
            return ["Using a page number that is less than 1"]
        case .unspecified:
            return []
        }
    }

    public var suggestedFixes: [String] {
        return []
    }
}
