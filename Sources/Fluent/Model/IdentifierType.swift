/// Supported model identifier types.
public enum IdentifierType<I: Identifier> {
    /// The identifier property on the model
    /// should always be `nil` when saving a new model.
    /// The database driver is expected to generate an
    /// autoincremented identifier based on previous
    /// identifiers that exist in the database.
    case autoincrementing
    /// A closure that creates a new identifier.
    public typealias IdentifierFactory = () -> I
    /// The identifier property on the model should
    /// always be `nil` when saving a new model.
    /// The supplied `IdentifierFactory` will be used
    /// to generate a new identifier for new items.
    case generated(IdentifierFactory)
    /// The identifier property on the model should
    /// always be set when saving a new model.
    case supplied
}
