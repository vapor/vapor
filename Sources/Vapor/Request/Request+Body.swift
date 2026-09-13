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

        /// The buffered body, or `nil` if there is none or nothing has collected it yet.
        ///
        /// Bodies are lazy, so this is `nil` until something asks for the bytes. Use ``data(max:)``
        /// to collect the body and always get what is there.
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

        /// The buffered body as UTF-8, or `nil` if there is none or nothing has collected it yet.
        ///
        /// Use ``string(max:)`` to collect the body and always get what is there.
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
        /// - Parameter max: The ceiling. Defaults to ``BodySizeLimit/default``, this request's
        ///   ``Request/maxBodySize``.
        ///
        /// For an unread stream, aborts with 413 if the declared `Content-Length` already exceeds the
        /// ceiling before reading anything; an under-declaring client is still caught while collecting.
        /// An already-buffered (or absent) body is returned as is — it was accepted under its original
        /// limit, so a smaller `max` on a later call doesn't re-reject it.
        public func collect(max: BodySizeLimit = .default) async throws -> Data? {
            let limit = max.bytes(default: self.request.maxBodySize.value)
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

        /// The body's bytes, collecting the stream first if nothing has collected it yet.
        ///
        /// The collecting counterpart to ``data``, and what most handlers want: it does not care
        /// whether the body arrived on a socket or was already materialised, and an
        /// already-collected body is returned without re-reading anything.
        ///
        /// - Parameter max: The ceiling, as ``collect(max:)``.
        /// - Returns: The body's bytes, or `nil` if the request has no body.
        /// - Throws: ``Abort`` with `.contentTooLarge` if the body exceeds `max`.
        public func data(max: BodySizeLimit = .default) async throws -> Data? {
            try await self.collect(max: max)
        }

        /// The body decoded as UTF-8, collecting the stream first if nothing has collected it yet.
        ///
        /// The collecting counterpart to ``string``. See ``data(max:)`` for the semantics; this
        /// decodes the result, substituting U+FFFD for any invalid UTF-8 rather than failing.
        ///
        /// - Parameter max: The ceiling, as ``collect(max:)``.
        /// - Returns: The body decoded as UTF-8, or `nil` if the request has no body.
        /// - Throws: ``Abort`` with `.contentTooLarge` if the body exceeds `max`.
        public func string(max: BodySizeLimit = .default) async throws -> String? {
            try await self.data(max: max).map { String(decoding: $0, as: UTF8.self) }
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
