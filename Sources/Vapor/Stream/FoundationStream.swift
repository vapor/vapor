#if !os(Linux)

    import Foundation

    public class FoundationStream: NSObject, Stream, ClientStream, NSStreamDelegate {
        public enum Error: ErrorProtocol {
            case unableToCompleteWriteOperation
            case unableToConnectToHost
            case unableToUpgradeToSSL
        }

        public func setTimeout(_ timeout: Double) throws {
            throw StreamError.unsupported
        }

        public var closed: Bool {
            return input.streamStatus == .closed
                || output.streamStatus == .closed
        }

        let input: NSInputStream
        let output: NSOutputStream

        public required init(host: String, port: Int) throws {
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

        // MARK: Connect

        public func connect() throws -> Stream {
            input.open()
            output.open()
            return self
        }

        // MARK: Stream Events

        public func stream(_ aStream: NSStream, handle eventCode: NSStreamEvent) {
            if eventCode.contains(.endEncountered) { _ = try? close() }
        }
    }

    // TODO: Fix foundation stream
    
    extension NSStream {
        func upgradeSSL() -> Bool {
            return setProperty(NSStreamSocketSecurityLevelNegotiatedSSL, forKey: NSStreamSocketSecurityLevelKey)
        }
    }

    public final class SecureFoundationStream: FoundationStream {
        public override func connect() throws -> Stream {
            Log.warning("Using Secure Foundation Stream -- This is NOT supported on linux. Make sure to visit https://github.com/qutheory/vapor-ssl")
            _ = input.upgradeSSL()
            _ = output.upgradeSSL()
            return try super.connect()
        }
    }

#endif
