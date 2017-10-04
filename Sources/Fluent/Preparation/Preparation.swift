/// A preparation prepares the database for
/// any task that it may need to perform during runtime.
public protocol Preparation {

    /// The prepare method should call any methods
    /// it needs on the database to prepare.
    static func prepare(_ database: Database) throws

    /// The revert method should undo any actions
    /// caused by the prepare method.
    ///
    /// If this is impossible, the `PreparationError.revertImpossible`
    /// error should be thrown.
    static func revert(_ database: Database) throws
}
