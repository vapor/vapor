#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Hummingbird

private let headerEndOfLine = "\r\n"
private let newLine: Byte = 10
private let carriageReturn: Byte = 13
private let minimumValidAsciiCharacter = carriageReturn + 1

// MARK: Byte => Character
extension Character {
    init(_ byte: Byte) {
        let scalar = UnicodeScalar(byte)
        self.init(scalar)
    }
}

public class HummingbirdServer: Server {

    // MARK: Sockets
    private var socket: Hummingbird.Socket?
    //private var activeSockets = ThreadSafeSocketStore<Socket>()


    // MARK: S4.Server
    public var ip: String?
    public var delegate: Responder!

    public func serve(responder: Responder, at port: Int) throws {
        halt()
        self.delegate = responder

        let socket = try Hummingbird.Socket.makeStreamSocket()
        try socket.bind(toAddress: ip, onPort: "\(port)")
        try socket.listen(pendingConnectionBacklog: 100)

        self.socket = socket

        do {
            try socket.accept(Int(SOMAXCONN), connectionHandler: self.handle)
        } catch {
            Log.error("Failed to accept: \(socket) error: \(error)")
        }
    }

    public func halt() {
        do {
            try socket?.close()
        } catch {
            Log.warning("Could not halt server")
        }
    }

    private func handle(socket: Hummingbird.Socket) {
        do {
            try Background {
                do {
                    var keepAlive = false
                    repeat {
                        let request = try socket.readRequest()
                        let response = try self.delegate.respond(request)
                        try socket.write(response, keepAlive: keepAlive)
                        keepAlive = request.supportsKeepAlive
                    } while keepAlive

                    try socket.close()
                } catch {
                    Log.error("Request Handle Failed: \(error)")
                }
            }
        } catch {
            Log.error("Backgrounding Handler Failed: \(error)")
        }
    }

}

extension Request {
    var supportsKeepAlive: Bool {
        for value in headers["Connection"] ?? [] {
            if value.trim() == "keep-alive" {
                return true
            }
        }
        return false
    }
}

extension Response {
    static func notFound() -> Response {
        return Response(error: "Not Found")
    }
}

extension Hummingbird.Socket {

    func writeHeader(line line: String) throws {
        try write(line + headerEndOfLine)
    }

    func writeHeader(key key: String, val: String) throws {
        try writeHeader(line: "\(key): \(val)")
    }

    func write(string: String) throws {
        try write(string.data)
    }

    public func write(data: Data) throws {
        try send(data.bytes)
    }

    public func nextByte() throws -> Byte? {
        return try receive(maximumBytes: 1).first
    }

    internal func readLine() throws -> String {
        var line: String = ""
        func append(byte: Byte) {
            // Possible minimum bad name here because we expect `>=`. Or make minimum '14'
            guard byte >= minimumValidAsciiCharacter else { return }
            line.append(Character(byte))
        }

        while let next = try nextByte() where next != newLine {
            append(next)
        }

        return line
    }


    private func write(response: Response, keepAlive: Bool) throws {
        let version = response.version
        let status = response.status

        let statusLine = "HTTP/\(version.major).\(version.minor) \(status.statusCode) \(status.reasonPhrase)"
        try writeHeader(line: statusLine)

        if keepAlive {
            try writeHeader(key: "Connection", val: "keep-alive")
        }

        try response.headers.forEach { (key, values) in
            for value in values {
                try writeHeader(key: key.string, val: value)
            }
        }
        try write(headerEndOfLine)

        switch response.body {
        case .buffer(let data):
            try write(data)
        case .receiver(let receiver):
            while !receiver.closed {
                let chunk = try receiver.receive()
                try write(chunk)
            }
        case .sender(let closure):
            let stream = makeStream()
            try closure(stream)
        }
    }

    func readRequest() throws -> Request {
        let header = try HummingbirdHeader(self)

        let bytes: [UInt8]
        if let length = header.fields["Content-Length"], let bufferSize = Int(length) {
            bytes = try receive(maximumBytes: bufferSize)
        } else {
            bytes = []
        }
        let data = Data(bytes)

        return try makeRequest(header, body: data)
    }

    func makeRequest(header: HummingbirdHeader, body data: Data) throws -> Request {
        let requestLine = header.requestLine

        //Method
        let method: Request.Method
        switch requestLine.method.lowercased() {
        case "get":
            method = .get
        case "delete":
            method = .delete
        case "head":
            method = .head
        case "post":
            method = .post
        case "put":
            method = .put
        case "connect":
            method = .connect
        case "options":
            method = .options
        case "trace":
            method = .trace
        case "patch":
            method = .patch
        default:
            method = .other(method: requestLine.method)
        }

        //URI
        let pathParts = requestLine.uri.split("?", maxSplits: 1)
        let path = pathParts.first ?? ""
        let queryString = pathParts.last ?? ""
        let queryParts = queryString.split("&")

        var queries: [URI.Query] = []
        for part in queryParts {
            let parts = part.split("=")

            let value: String?

            if let v = parts.last {
                value = (try? String(percentEncoded: v)) ?? v
            } else {
                value = nil
            }

            let query = URI.Query(key: parts.first ?? "", value: value)
            queries.append(query)
        }


        let uri = URI(scheme: "http", userInfo: nil, host: nil, port: nil, path: path, query: queries, fragment: nil)

        //Headers
        var headers = Headers([:])
        for (key, value) in header.fields {
            headers[Headers.Key(key)] = Headers.Values(value)
        }

        return Request(method: method, uri: uri, headers: headers, body: data)
    }
}
