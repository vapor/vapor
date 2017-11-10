import Foundation

/// Has create and update timestamps.
public protocol SoftDeletable {
    /// The date at which this model was deleted.
    /// nil if the model has not been deleted yet.
    /// If this property is true, the model will not
    /// be included in any query results unless
    /// `.withSoftDeleted()` is used.
    var deletedAt: Date? { get set }
}

extension DatabaseQuery {
    /// If true, soft deleted models should be included.
    internal var withSoftDeleted: Bool {
        get { return extend["withSoftDeleted"] as? Bool ?? false }
        set { extend["withSoftDeleted"] = newValue }
    }
}

extension QueryBuilder where Model: SoftDeletable {
    /// Includes soft deleted models in the results.
    public func withSoftDeleted() {
        query.withSoftDeleted = true
    }
}
