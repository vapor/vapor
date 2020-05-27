import NIO

/// Unix domain socket errors may be thrown when attepting to start the server from a unix domain socket path.
public enum UnixDomainSocketPathError: AbortError {
    case inaccessible(IOError)
    case unsupportedFile(mode_t, String)
    case couldNotRemove(IOError)
    case socketInUse(IOError)
    case noSuchDirectory(IOError)
    
    /// See `AbortError.status`
    public var status: HTTPResponseStatus {
        return .internalServerError
    }

    /// See `AbortError.identifier`
    public var identifier: String {
        switch self {
        case .inaccessible: return "inaccessible"
        case .unsupportedFile: return "unsupportedFile"
        case .couldNotRemove: return "couldNotRemove"
        case .socketInUse: return "socketInUse"
        case .noSuchDirectory: return "noSuchDirectory"
        }
    }
    
    /// See `CustomStringConvertible`.
    public var description: String {
        return "Unix Domain Socket Path error: \(self.reason)"
    }

    /// See `AbortError.reason`
    public var reason: String {
        switch self {
        case .inaccessible(let ioError), .couldNotRemove(let ioError), .socketInUse(let ioError), .noSuchDirectory(let ioError):
            return ioError.description
        case .unsupportedFile(_, let message):
            return message
        }
    }
}
