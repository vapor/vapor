import Foundation

/// Has create and update timestamps.
public protocol Timestampable {
    /// The date at which this model was created.
    /// nil if the model has not been created yet.
    var createdAt: Date? { get set }

    /// The date at which this model was last updated.
    /// nil if the model has not been created yet.
    var updatedAt: Date? { get set }
}

//extension SchemaCreator where Model: Timestampable {
//    /// Adds createdAt and updatedAt timestamps to the schema.
//    public func timestamps() {
//        field(for: \.createdAt)
//        field(for: \.updatedAt)
//    }
//}

