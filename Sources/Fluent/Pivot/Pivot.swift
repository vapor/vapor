/// Capable of being a pivot between two
/// models. Usually in a Siblings relation.
/// note: special care must be taken when using pivots
/// with equal left and right types.
public protocol Pivot: Model {
    /// The Left model for this pivot.
    /// note: a pivot with opposite right/left is distinct.
    associatedtype Left: Model

    /// The Right model for this pivot.
    /// note: a pivot with opposite right/left is distinct.
    associatedtype Right: Model

    typealias LeftIDKey = ReferenceWritableKeyPath<Self, Left.ID>
    static var leftIDKey: LeftIDKey { get }

    typealias RightIDKey = ReferenceWritableKeyPath<Self, Right.ID>
    static var rightIDKey: RightIDKey { get }
}

/// A pivot that can be initialized from just
/// the left and right models. This allows
/// Fluent to automatically create pivots for
/// extended functionality.
/// ex: attach, detach, isAttached
/// note: pivots with equal left and right types
/// cannot take advantage of this protocol due to
/// ambiguous type errors.
public protocol ModifiablePivot: Pivot {
    init(_ left: Left, _ right: Right) throws
}

extension Pivot {
    /// See Model.entity
    public static var name: String {
        if Left.name < Right.name {
            return "\(Left.name)+\(Right.name)"
        } else {
            return "\(Right.name)+\(Left.name)"
        }
    }

    /// See Model.entity
    public static var entity: String {
        return name
    }
}
