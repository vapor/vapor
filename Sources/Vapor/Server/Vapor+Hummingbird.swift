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

}
