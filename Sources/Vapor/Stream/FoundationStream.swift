//#if !os(Linux)
//
//    import Foundation
//
//    public class FoundationStream: NSObject, Stream, ClientStream, Foundation.StreamDelegate {
//        public enum Error: ErrorProtocol {
//            case unableToCompleteReadOperation
//            case unableToCompleteWriteOperation
//            case unableToConnectToHost
//            case unableToUpgradeToSSL
//        }
//
//        public func setTimeout(_ timeout: Double) throws {
//            throw StreamError.unsupported
//        }
//
//        public var closed: Bool {
//            return input.streamStatus == .closed
//                || output.streamStatus == .closed
//        }
//
//        public let host: String
//        public let port: Int
//        public let securityLayer: SecurityLayer
//        let input: InputStream
//        let output: NSOutputStream
//
//        public required init(host: String, port: Int, securityLayer: SecurityLayer) throws {
//            self.host = host
//            self.port = port
//            self.securityLayer = securityLayer
//            var inputStream: InputStream? = nil
//            var outputStream: NSOutputStream? = nil
//            Foundation.Stream.getStreamsToHost(withName: host,
//                                      port: port,
//                                      inputStream: &inputStream,
//                                      outputStream: &outputStream)
//            guard
//                let input = inputStream,
//                let output = outputStream
//                else { throw Error.unableToConnectToHost }
//            self.input = input
//            self.output = output
//            super.init()
//
//            self.input.delegate = self
//            self.output.delegate = self
//        }
//
//        public func close() throws {
//            output.close()
//            input.close()
//        }
//
//        func send(_ byte: Byte) throws {
//            try send([byte])
//        }
//
//        public func send(_ bytes: Bytes) throws {
//            guard !bytes.isEmpty else { return }
//            
//            var buffer = bytes
//            let written = output.write(&buffer, maxLength: buffer.count)
//            guard written == bytes.count else {
//                throw Error.unableToCompleteWriteOperation
//            }
//        }
//
//        public func flush() throws {}
//
//        public func receive() throws -> Byte? {
//            return try receive(max: 1).first
//        }
//
//        public func receive(max: Int) throws -> Bytes {
//            var buffer = Bytes(repeating: 0, count: max)
//            let read = input.read(&buffer, maxLength: max)
//            guard read != -1 else { throw Error.unableToCompleteReadOperation }
//            return buffer.prefix(read).array
//        }
//
//        // MARK: Connect
//
//        public func connect() throws -> Stream {
//            if securityLayer == .tls {
//                _ = input.upgradeSSL()
//                _ = output.upgradeSSL()
//            }
//            input.open()
//            output.open()
//            return self
//        }
//
//        // MARK: Stream Events
//
//        public func stream(_ aStream: Foundation.Stream, handle eventCode: Foundation.Stream.Event) {
//            if eventCode.contains(.endEncountered) { _ = try? close() }
//        }
//    }
//
//    extension Foundation.Stream {
//        func upgradeSSL() -> Bool {
//            return setProperty(Foundation.StreamSocketSecurityLevel.negotiatedSSL,
//                               forKey: Foundation.Stream.PropertyKey.socketSecurityLevelKey.rawValue)
//        }
//    }
//
//#endif
