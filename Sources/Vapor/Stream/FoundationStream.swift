#if !os(Linux)

    import Foundation

    public final class FoundationStream: NSObject, Stream, NSStreamDelegate {
        public enum Error: ErrorProtocol {
            case unableToCompleteWriteOperation
            case unableToConnectToHost
            case unableToUpgradeToSSL
        }

        public var timeout: Double = 0

        public var closed: Bool {
            return input.streamStatus == .closed
                || output.streamStatus == .closed
        }

        let input: NSInputStream
        let output: NSOutputStream

        init(host: String, port: Int) throws {
            var inputStream: NSInputStream? = nil
            var outputStream: NSOutputStream? = nil
            NSStream.getStreamsToHost(withName: host,
                                      port: port,
                                      inputStream: &inputStream,
                                      outputStream: &outputStream)
            guard
                let input = inputStream,
                let output = outputStream
                else { throw Error.unableToConnectToHost }
            input.open()
            output.open()
            self.input = input
            self.output = output
            super.init()

            self.input.delegate = self
            self.output.delegate = self
        }

        public func close() throws {
            output.close()
            input.close()
        }

        func send(_ byte: Byte) throws {
            try send([byte])
        }

        public func send(_ bytes: Bytes) throws {
            var buffer = bytes
            let written = output.write(&buffer, maxLength: buffer.count)
            guard written == bytes.count else {
                throw Error.unableToCompleteWriteOperation
            }
        }

        public func flush() throws {}

        public func receive() throws -> Byte? {
            return try receive(max: 1).first
        }

        public func receive(max: Int) throws -> Bytes {
            var buffer = Bytes(repeating: 0, count: max)
            let read = input.read(&buffer, maxLength: max)
            return buffer.prefix(read).array
        }

        // MARK: Stream Events

        public func stream(_ aStream: NSStream, handle eventCode: NSStreamEvent) {
            if eventCode.contains(.endEncountered) { _ = try? close() }
        }
    }

    /*
 extension FoundationStream: ClientStream {
        public static func makeConnection(host: String, port: Int, secure: Bool) throws -> Stream {
            let stream = try FoundationStream(host: host, port: port)
            if secure {
                guard stream.output.upgradeSSL() else { throw Error.unableToUpgradeToSSL }
                guard stream.input.upgradeSSL() else { throw Error.unableToUpgradeToSSL }
            }
            return stream
        }
    }*/

    // TODO: Fix foundation stream
    
    extension NSStream {
        func upgradeSSL() -> Bool {
            return setProperty(NSStreamSocketSecurityLevelNegotiatedSSL, forKey: NSStreamSocketSecurityLevelKey)
        }
    }

#endif
