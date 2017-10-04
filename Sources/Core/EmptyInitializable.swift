/// Types conforming to this protocol can be
/// initialized with no arguments (or all default arguments).
///
/// This can be used to enable convenience static calls for instance methods.
public protocol EmptyInitializable {
    init() throws
}
