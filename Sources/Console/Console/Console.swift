import Async

/// Protocol for powering styled Console I/O.
public protocol Console: Extendable {
    /// Handles all input/output/error/clear/execute commands
    /// supported by the `Action` enum.
    @discardableResult
    func action(_ action: ConsoleAction) throws -> String?

    /// The size of the console window used for
    /// calculating lines printed and centering tet.
    var size: (width: Int, height: Int) { get }
}
