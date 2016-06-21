public enum ProgramStreamError: ErrorProtocol {
    case unsupportedScheme
}

public protocol ProgramStream {
    init(scheme: String, host: String, port: Int) throws
}

public protocol ClientStream: ProgramStream {
    func connect() throws -> Stream
}
