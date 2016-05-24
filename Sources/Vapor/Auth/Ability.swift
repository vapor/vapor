/**
 * An ability encompasses an action
 * and any type to perform that on.
 * Like "update" a `Post`.
 */
public enum Action: String {
    case list, inspect, create, update, delete
}

public struct Ability<Object>: Equatable {
    public let action: Action
    public let type: Object.Type
}

public func ==<Object1, Object2>(lhs: Ability<Object1>, rhs: Ability<Object2>) -> Bool {
    return lhs.action == rhs.action && lhs.type == rhs.type
}
