import BasicContainers
import NIOHTTPServer

/// Holds the server's move-only response writer for the duration of one response
final class NIOHTTPBodyWriterStorage {
    private var inner: NIOHTTPServer.ResponseSender.Writer?

    /// Whether the response was deliberately left unfinished.
    ///
    /// Once the head is flushed it cannot be retracted, so a body that fails part-way is reported by
    /// *not* sending a terminating chunk: the client sees a truncated response rather than a
    /// well-formed short one. `NIOHTTPServer.ResponseSender.Writer` has no `fail` of its own — the
    /// supported way to abort is to throw out of the request handler, which makes the server close
    /// the connection without that chunk. So an abandoned writer is always about to be followed by a
    /// throw, but `deinit` cannot see a throw, which is why abandoning has to be recorded here to be
    /// told apart from simply forgetting to finish.
    private var wasAbandoned = false

    /// The number of body bytes written so far, used to check a stream against its declared length.
    private(set) var bytesWritten = 0

    init(inner: consuming NIOHTTPServer.ResponseSender.Writer) {
        self.inner = consume inner
    }

    /// Records that this response is being left unfinished on purpose, just before the handler
    /// throws to have the server abort it.
    func abandon() {
        self.wasAbandoned = true
    }

    func write(_ bytes: Span<UInt8>) async throws {
        // We need to copy here so the writer takes ownership of the data
        // TODO: This should be fixed in HTTP Server to avoid the copy
        var out = UniqueArray<UInt8>(minimumCapacity: bytes.count)
        out.append(copying: bytes)
        try await self.inner?.write(buffer: &out)
        self.bytesWritten += bytes.count
    }

    func write(_ bytes: some Sequence<UInt8>) async throws {
        var out = UniqueArray<UInt8>(minimumCapacity: bytes.underestimatedCount)
        // Staging is synchronous, so the sequence's own storage can be borrowed rather than copied
        // element by element; only the transport write is awaited, after the borrow has ended.
        let borrowed: Void? = bytes.withContiguousStorageIfAvailable { buffer in
            unsafe out.append(copying: buffer)
        }
        if borrowed == nil {
            out.append(copying: bytes)
        }
        // `write` drains `out`, so the count has to be taken first.
        let count = out.count
        try await self.inner?.write(buffer: &out)
        self.bytesWritten += count
    }

    func finish(_ trailingHeaders: HTTPFields?) async throws {
        guard let writer = self.inner.take() else { return }
        var empty = UniqueArray<UInt8>()
        try await writer.finish(buffer: &empty, finalElement: trailingHeaders)
    }

    deinit {
        // Finishing is async and cannot be done from here, so this only reports the mistake.
        // A writer released still holding the server's, without anyone having said the response was
        // being abandoned, is one that nobody finished. That surfaces later as `NIOAsyncWriter`'s
        // own `deinit` precondition, which names neither the response nor the layer responsible.
        // (The trap the test suite used to hit was not this layer: it was swift-http-server's accept
        // loop dropping buffered connections when the serve task is cancelled. The assert stays so
        // that if this layer ever is the culprit, the failure says so.)
        assert(
            self.inner == nil || self.wasAbandoned,
            "Response body writer was released without being finished or abandoned. Every path out of a streaming response must call finish(_:) or abandon()."
        )
    }
}
