/**
 * An ability encompasses an action
 * and any type to perform that on.
 * Like "update" a `Post`.
 */
public enum Action: String {
    case list, inspect, create, update, delete
}

public struct Ability<T>: Equatable {
    public let action: Action
    public let model: T.Type
}

public func ==<T, U>(lhs: Ability<T>, rhs: Ability<U>) -> Bool {
    return "\(lhs)" == "\(rhs)"
}
