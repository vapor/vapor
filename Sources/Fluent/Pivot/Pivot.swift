public protocol Pivot: Model {
    associatedtype Left: Model
    associatedtype Right: Model

    var leftID: Left.I { get set }
    var rightID: Right.I { get set }
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
