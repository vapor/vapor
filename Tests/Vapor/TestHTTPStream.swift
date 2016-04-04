@testable import Vapor

final class TestHTTPStream: HTTPStream {
    enum Error: ErrorProtocol {
        case Closed
    }

    var buffer: Data
    var handler: (HTTPStream -> Void)?

    init() {
        buffer = []
    }

    static func makeStream() -> TestHTTPStream {
        return TestHTTPStream()
    }

    func accept(max connectionCount: Int, handler: (HTTPStream -> Void)) throws {
        print("Accepting max: \(connectionCount)")
        self.handler = handler
    }

    func bind(to ip: String?, on port: Int) throws {
        print("Binding to \(ip) on \(port)")
    }

    func listen() throws {
        print("Listening...")
    }

    var closed: Bool = false

    func close() -> Bool {
        if !closed {
            closed = true
            return true
        }
        return false
    }

    func receive(max byteCount: Int) throws -> Data {
        if buffer.count == 0 {
            close()
            return []
        }

        if byteCount >= buffer.count {
            close()
            let data = buffer
            buffer = []
            return data
        }

        let data = buffer.bytes[0..<byteCount]
        buffer.bytes.removeFirst(byteCount)

        let result = Data(data)
        return result
    }

    func send(data: Data) throws {
        closed = false
        buffer.append(contentsOf: data)
    }
    
    func flush() throws {
        
    }
    
}