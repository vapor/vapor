/// A pivot between two many-to-many
/// database entities.
///
/// For example: users > users+teams < teams
///
/// let teams = users.teams()
public protocol PivotProtocol {
    associatedtype Left: Model
    associatedtype Right: Model

    init(leftId: Encodable, rightId: Encodable)

    /// Returns true if the two entities are related
    static func related(_ left: Left, _ right: Right) throws -> Bool

    /// Attaches the two entities
    /// Entities must be saved before attempting attach.
    @discardableResult
    static func attach(_ left: Left, _ right: Right) throws -> Self

    /// Detaches the two entities.
    /// Entities must be saved before attempting detach.
    static func detach(_ left: Left, _ right: Right) throws
}

/// PivotProtocol methods that come
/// pre-implemented if the Pivot conforms to Entity
extension PivotProtocol where Self: Model {
    /// See PivotProtocol.related
    public static func related(_ left: Left, _ right: Right) throws -> Bool {
        let leftId = try left.requireExists()
        let rightId = try right.requireExists()

        let results = try makeQuery()
            .filter(Left.idKey, leftId)
            .filter(Right.idKey, rightId)
            .first()

        return results != nil
    }

    /// See PivotProtocol.attach
    @discardableResult
    public static func attach(_ left: Left, _ right: Right) throws -> Self {
        let leftId = try left.requireExists()
        let rightId = try right.requireExists()

        let pivot = self.init(leftId: leftId, rightId: rightId)
        try pivot.save()

        return pivot
    }

    /// See PivotProtocol.detach
    public static func detach(_ left: Left, _ right: Right) throws {
        let leftId = try left.requireExists()
        let rightId = try right.requireExists()

        try makeQuery()
            .filter(Left.idKey, leftId)
            .filter(Right.idKey, rightId)
            .delete()
    }
}
