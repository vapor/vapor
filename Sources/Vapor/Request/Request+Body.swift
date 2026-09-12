#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif
import HTTPTypes
import Synchronization

extension Request {
    public struct Body: CustomStringConvertible, Sendable {
        let request: Request

        init(_ request: Request) {
            self.request = request
        }

        /// The buffered body, or `nil` if there is none or it is still an unread stream.
        /// Call ``collect(max:)`` first to buffer a streamed body.
        public var data: Data? {
            switch self.request.bodyStorage.storage.withLock({ $0 }) {
            case .collected(let data): return data
            case .none, .stream: return nil
            }
        }

        /// Bytes of this body that have actually been read, whether or not they were kept.
        ///
        /// For metrics, which run after the responder chain and need a size even for a body nothing
        /// collected — a 404 on an upload, a webhook that only checked a header.
        package var bytesRead: Int {
            switch self.request.bodyStorage.storage.withLock({ $0 }) {
            case .collected(let data): return data.count
            case .stream(let stream): return stream.bytesConsumed
            case .none: return 0
            }
        }

        public var string: String? {
            if let data = self.data {
                return String(decoding: data, as: UTF8.self)
            } else {
                return nil
            }
        }

        /// Lends a ``RequestBodyReader`` for the duration of `body`, so the handler can drive the read
        /// loop itself (read a single chunk, interleave reads with other work). The reader is
        /// non-escapable: using it after the request moved on is a compile-time error.
        ///
        /// - Important: Reading directly bypasses ``Request/maxBodySize``, which only
        ///   ``collect(max:)`` enforces. A handler driving the read loop itself is choosing to take
        ///   the body in unbounded pieces, so bounding it is that handler's job — count the bytes it
        ///   keeps, or call ``collect(max:)`` instead.
        public func withReader<R>(
            _ body: (borrowing any RequestBodyReader & ~Escapable) async throws -> R
        ) async throws -> R {
            let stream: RequestBodyStream
            switch self.request.bodyStorage.storage.withLock({ $0 }) {
            case .stream(let live):
                stream = live
            case .collected(let data):
                // A body already in memory replays through the same stream type, so reading is the
                // same whether it arrived on a socket or not. Each lend gets its own replay.
                stream = RequestBodyStream(collected: data)
            case .none:
                stream = RequestBodyStream(collected: nil)
            }
            let scope = RequestBodyReaderScope()
            let reader = NIORequestBodyReader(stream, scope: scope)
            return try await body(reader)
        }

        /// Drives the read loop for you, calling `body` with each chunk of the request body. This is
        /// what most streaming handlers want; it is a convenience over ``withReader(_:)`` and shares
        /// its semantics with ``RequestBodyReader/forEachChunk(_:)`` (borrowed span, valid only for the
        /// call — copy out anything you keep).
        public func forEachChunk(_ body: (Span<UInt8>) async throws -> Void) async throws {
            try await self.withReader { reader in
                try await reader.forEachChunk(body)
            }
        }

        /// Buffers the body into memory, aborting with 413 if it exceeds the ceiling.
        ///
        /// - Parameter max: The ceiling in bytes, or `nil` for this request's
        ///   ``Request/maxBodySize`` — which is the application default unless the route or a
        ///   middleware changed it. Pass `Int.max` for no ceiling at all.
        ///
        /// For an unread stream, aborts with 413 if the declared `Content-Length` already exceeds the
        /// ceiling before reading anything; an under-declaring client is still caught while collecting.
        /// An already-buffered (or absent) body is returned as is — it was accepted under its original
        /// limit, so a smaller `max` on a later call doesn't re-reject it.
        public func collect(max: Int? = nil) async throws -> Data? {
            let limit = max ?? self.request.maxBodySize.value
            switch self.request.bodyStorage.storage.withLock({ $0 }) {
            case .stream(let stream):
                // Reject early on an over-limit declared length, before reading any body. This lives
                // in the `.stream` case on purpose: a `.collected`/`.none` body is already
                // materialised (or absent), so this must not spuriously 413 an accepted request when
                // it is re-collected with a smaller `max`.
                let declaredLength = self.request.headers[.contentLength].flatMap { Int($0) }
                if let declaredLength, declaredLength > limit {
                    throw Abort(.contentTooLarge, headers: .connectionClose)
                }
                // A stream drains once, so cache the result as `.collected` for later `data`/`collect`/`decode`.
                let buffer = try await stream.collect(max: limit, expecting: declaredLength)
                self.request.bodyStorage.storage.withLock { $0 = .collected(buffer) }
                return buffer
            case .collected(let data):
                return data
            case .none:
                return nil
            }
        }

        public var description: String {
            if let data = self.data {
               return String(decoding: data, as: UTF8.self)
            } else {
                return ""
            }
        }
    }
}
