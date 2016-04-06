import Hummingbird

typealias Socket = Hummingbird.Socket

extension Hummingbird.Socket: HTTPStream {
    static func makeStream() -> Hummingbird.Socket {
        return try! Hummingbird.Socket.makeStreamSocket()
    }

    func accept(max connectionCount: Int, handler: (HTTPStream -> Void)) throws {
        try accept(Int(SOMAXCONN), connectionHandler: handler)
    }

    func bind(to ip: String?, on port: Int) throws {
        try bind(toAddress: ip, onPort: "\(port)")

    }

    func listen() throws {
        try listen(pendingConnectionBacklog: 100)
    }

    enum Error: ErrorProtocol {
        case Unsupported
    }

    public var closed: Bool {
        return false
    }

    public func close() -> Bool {
        return false
    }

    public func receive(max maxBytes: Int) throws -> Data {
        let bytes: [Byte] = try self.receive(maximumBytes: maxBytes) ?? []
        return Data(bytes)
    }

    public func send(data: Data) throws {
        try self.send(data.bytes)
    }

    public func flush() throws {
        throw Error.Unsupported
    }

}
