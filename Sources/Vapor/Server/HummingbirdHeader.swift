// HEADERS
// https://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html
import Hummingbird

internal struct HummingbirdHeader {
    enum Error: ErrorProtocol {
        case InvalidHeaderKeyPair
    }

    let requestLine: RequestLine
    private(set) var fields: [String : String] = [:]

    var fieldsArray: [(String, String)] {
        var array: [(String, String)] = []
        for (key, val) in fields {
            array.append((key, val))
        }
        return array
    }

    init(_ socket: Hummingbird.Socket) throws {
        let requestLineRaw = try socket.readLine()
        requestLine = try RequestLine(requestLineRaw)
        try collectHeaderFields(socket)
    }

    init(requestLine: RequestLine) {
        self.requestLine = requestLine
    }

    private mutating func collectHeaderFields(socket: Hummingbird.Socket) throws {
        while let line = try nextHeaderLine(socket) {
            let (key, val) = try extractKeyPair(line)
            fields[key] = val
        }
    }

    private func nextHeaderLine(socket: Hummingbird.Socket) throws -> String? {
        let next = try socket.readLine()
        if !next.isEmpty {
            return next
        } else {
            return nil
        }
    }

    private func extractKeyPair(line: String) throws -> (key: String, value: String) {
        let components = line.split(":", maxSplits: 1)
        // Is this safe? It doesn't assert count == 2, so no `:` might get mapped directly
        // Drop first to remove leading ` ` key is actually `: `, but doesn't support splitting on substring, only char
        guard let key = components.first, let val = components.last?.characters.dropFirst() else { throw Error.InvalidHeaderKeyPair }

        return (key, String(val))
    }
}

extension HummingbirdHeader: CustomStringConvertible {
    var description: String {
        var fieldsDescription = ""
        fields.forEach { key, val in
            Log.info("K**\(key)**")
            fieldsDescription += "    \(key): \(val)\n"
        }
        return "\n\(requestLine)\n\n\(fieldsDescription)"
    }
}

// MARK: RequestLine

extension HummingbirdHeader {
    // https://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html
    // Request-Line   = Method SP Request-URI SP HTTP-Version CRLF
    internal struct RequestLine {
        enum Error: ErrorProtocol {
            case InvalidComponents
        }

        let method: String
        let uri: String
        let version: String

        init(_ string: String) throws {
            let comps = string.split(" ")
            guard comps.count == 3 else {
                throw Error.InvalidComponents
            }

            method = comps[0]
            uri = comps[1]
            version = comps[2]
        }
    }

}

extension HummingbirdHeader.RequestLine: CustomStringConvertible {
    var description: String {
        return "\nMethod: \(method)\nUri: \(uri)\nVersion: \(version)"
    }
}
