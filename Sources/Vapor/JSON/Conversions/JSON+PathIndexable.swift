import PathIndexable

extension JSON: PathIndexable {
    public var pathIndexableObject: [String: JSON]? {
        switch self {
        case .object(let object):
            return object
        default:
            return nil
        }
    }

    public var pathIndexableArray: [JSON]? {
        switch self {
        case .array(let array):
            return array
        default:
            return nil
        }
    }
}
