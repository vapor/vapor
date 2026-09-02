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
        ///
        /// Aborts with 413 if the declared `Content-Length` already exceeds `max`, before reading any
        /// body. A client that under-declares is still caught while streaming as the body is collected.
        public func collect(max: Int? = 1 << 14) async throws -> ByteBuffer? {
            // Reject early on an over-limit declared length; skip when there's no limit or no header.
            let declaredLength = self.request.headers[.contentLength].flatMap { Int($0) }
            let exceedsDeclaredLimit = if let max, let declaredLength { declaredLength > max } else { false }
            guard !exceedsDeclaredLimit else {
                throw Abort(.contentTooLarge)
            }
            switch self.request.bodyStorage.withLockedValue({ $0 }) {
            case .stream(let stream):
                // A stream drains once, so cache the result as `.collected` for later `data`/`collect`/`decode`.
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
