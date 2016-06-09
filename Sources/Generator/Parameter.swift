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

    var isWildcard: Bool {
        switch self {
        case.wildcard(_):
            return true
        default:
            return false
        }
    }

    static func pathFor(_ array: [Parameter]) -> Parameter {
        var i = 0

        for item in array {
            if item.isPath {
                i += 1
            }
        }

        let path = Path(name: "p\(i)")
        return .path(path)
    }

    static func wildcardFor(_ array: [Parameter]) -> Parameter {
        var i = 0

        for item in array {
            if item.isWildcard {
                i += 1
            }
        }

        let path = Wildcard(name: "w\(i)", generic: "W\(i)")
        return .wildcard(path)
    }
}