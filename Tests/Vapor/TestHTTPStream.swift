@testable import Vapor

final class TestHTTPStream: HTTPListenerStream {
    enum Error: ErrorProtocol {
        case Closed
    }

    var buffer: Data
    var handler: (HTTPStream -> Void)?

    init() {
        buffer = []
    }

    convenience init(address: String?, port: Int) throws {
        self.init()
    }

    func accept(max connectionCount: Int, handler: (HTTPStream -> Void)) throws {
        print("Accepting max: \(connectionCount)")
        self.handler = handler
    }

    func bind() throws {
        print("Binding...")
    }

    func listen() throws {
        print("Listening...")
    }

    var closed: Bool = false

    func close() {
        if !closed {
            closed = true
        }
    }

    func receive(upTo byteCount: Int, timingOut deadline: Double = 0) throws -> Data {
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

    func send(_ data: Data, timingOut deadline: Double = 0) throws {
        closed = false
        buffer.append(contentsOf: data)
    }

    func flush(timingOut deadline: Double = 0) throws {
        print("flushing")
        buffer = Data()
    }
}