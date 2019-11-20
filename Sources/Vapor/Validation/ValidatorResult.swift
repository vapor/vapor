public protocol ValidatorResult: CustomStringConvertible {
    var failed: Bool { get }
}
