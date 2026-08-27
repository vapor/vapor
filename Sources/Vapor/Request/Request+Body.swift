#warning("Make this internal")
public import NIOCore
import NIOConcurrencyHelpers
import HTTPTypes

extension Request {
    public struct Body: CustomStringConvertible, Sendable {
        let request: Request

        init(_ request: Request) {
            self.request = request
        }

        /// The buffered body, or `nil` if there is none or it is still an unread stream.
        /// Call ``collect(max:)`` first to buffer a streamed body.
        public var data: ByteBuffer? {
            switch self.request.bodyStorage.withLockedValue({ $0 }) {
            case .collected(let buffer): return buffer
            case .none, .stream: return nil
            }
        }

        public var string: String? {
            if var data = self.data {
                return data.readString(length: data.readableBytes)
            } else {
                return nil
            }
        }

        /// Buffers the body into memory, up to `max` bytes (`nil` means no limit).
        public func collect(max: Int? = 1 << 14) async throws -> ByteBuffer? {
            switch self.request.bodyStorage.withLockedValue({ $0 }) {
            case .stream(let stream):
                // A stream can only be drained once, so cache the result as `.collected` for any
                // later `data`/`collect`/`decode` access.
                let buffer = try await stream.collect(max: max ?? .max)
                self.request.bodyStorage.withLockedValue { $0 = .collected(buffer) }
                return buffer
            case .collected(let buffer):
                return buffer
            case .none:
                return nil
            }
        }

        public var description: String {
            if var data = self.data,
                let description = data.readString(length: data.readableBytes) {
                return description
            } else {
                return ""
            }
        }
    }
}
