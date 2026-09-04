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

        /// Lends a ``RequestBodyReader`` for the duration of `body`, so the handler can drive the read
        /// loop itself (read a single chunk, interleave reads with other work). The reader is
        /// non-escapable: using it after the request moved on is a compile-time error.
        ///
        /// - Important: Reading directly bypasses the size ceiling that `.collect` / ``collect(max:)``
        ///   enforce — a `.stream` route is deliberately uncapped, so bounding the body is the handler's
        ///   job (track bytes read, or call ``collect(max:)`` instead).
        public func withReader<R>(
            _ body: (borrowing any RequestBodyReader & ~Escapable) async throws -> R
        ) async throws -> R {
            let source: NIORequestBodyReader.Source
            switch self.request.bodyStorage.withLockedValue({ $0 }) {
            case .stream(let stream):
                source = .stream(stream)
            case .collected(let buffer):
                source = .collected(CollectedBodyReplay(buffer))
            case .none:
                source = .collected(CollectedBodyReplay(nil))
            }
            let scope = RequestBodyReaderScope()
            let reader = NIORequestBodyReader(source, scope: scope)
            return try await body(reader)
        }

        /// Drives the read loop for you, calling `body` with each chunk of the request body as a
        /// borrowed ``RawSpan``. This is what most streaming handlers want.
        ///
        /// The span is only valid for the duration of each `body` call; copy out anything you need
        /// to keep beyond it.
        public func forEachChunk(_ body: (RawSpan) async throws -> Void) async throws {
            try await self.withReader { reader in
                try await reader.forEachChunk(body)
            }
        }

        /// Buffers the body into memory, up to `max` bytes (`nil` means no limit).
        ///
        /// For an unread stream, aborts with 413 if the declared `Content-Length` already exceeds `max`
        /// before reading anything; an under-declaring client is still caught while collecting. An
        /// already-buffered (or absent) body is returned as is — it was accepted under its original
        /// limit, so a smaller `max` on a later call doesn't re-reject it.
        public func collect(max: Int? = 1 << 14) async throws -> ByteBuffer? {
            switch self.request.bodyStorage.withLockedValue({ $0 }) {
            case .stream(let stream):
                // Reject early on an over-limit declared length, before reading any body. This lives
                // in the `.stream` case on purpose: a `.collected`/`.none` body is already
                // materialised (or absent), so this must not spuriously 413 an accepted request when
                // it is re-collected with a smaller `max`.
                let declaredLength = self.request.headers[.contentLength].flatMap { Int($0) }
                if let max, let declaredLength, declaredLength > max {
                    throw Abort(.contentTooLarge)
                }
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
