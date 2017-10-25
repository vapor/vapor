import Async

/// Fluent database models. These types can be fetched
/// from a database connection using a query.
///
/// Types conforming to this protocol provide the basis
/// fetching and saving data to/from Fluent.
public protocol Model: Codable {
    associatedtype I: Identifier

    /// This model's collection/table name
    static var entity: String { get }

    /// The model's identifier.
    var id: I? { get set }
}

/// Free implementations.
extension Model {
    /// See Model.entity
    public static var entity: String {
        return "\(Self.self)".lowercased() + "s"
    }
}

/// MARK: CRUD

extension Model {
    public mutating func save(
        to executor: QueryExecutor,
        new: Bool = false
    ) -> Future<Void> {
        return executor.query(Self.self).save(&self, new: new)
    }
}
