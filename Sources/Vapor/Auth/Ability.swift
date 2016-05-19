/**
 * An ability encompasses an action
 * and a `Model` to perform that on.
 * Like "update" a `Post`.
 */
public struct Ability: Equatable {
    public enum Action {
        case list, inspect, create, update, delete, other(String)
    }
    
    public let action: Action
    public let model: Model.Type
}

public func ==(lhs: Ability, rhs: Ability) -> Bool {
    return "\(lhs)" == "\(rhs)"
}
