enum Parameter {
    struct Wildcard {
        var name: String
        var generic: String
    }

    struct Path {
        var name: String
    }

    case path(Path)
    case wildcard(Wildcard)

    var name: String {
        switch self {
        case .path(let path):
            return path.name
        case .wildcard(let wildcard):
            return wildcard.name
        }
    }

    var isPath: Bool {
        switch self {
        case.path(_):
            return true
        default:
            return false
        }
    }
}