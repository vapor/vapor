import Foundation

/// A stream capable of being passed into
/// a console execute action as either input, output, or error.
public enum ExecuteStream {
    case fileHandle(FileHandle)
    case pipe(Pipe)
}

extension ExecuteStream {
    /// Returns either a Pipe or FileHandle.
    /// note: Foundation requires this, so can't avoid the Any type.
    internal var either: Any {
        switch self {
        case .fileHandle(let handle):
            return handle
        case .pipe(let pipe):
            return pipe
        }
    }
}
