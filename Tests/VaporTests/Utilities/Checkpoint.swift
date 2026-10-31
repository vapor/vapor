/// A one-shot event: `reach()` releases a `wait()`, whether it is already suspended or comes later.
///
/// For tests where one side of an exchange has to know the other has got somewhere — a handler is
/// blocked on a body, a first chunk has been read — before it acts. Waiting a fixed time for that
/// instead is a guess at how fast the machine is, and a loaded CI host outlasts any guess; waiting
/// on the event itself takes as long as it takes and no longer.
///
/// One waiter at a time: the stream underneath supports a single consumer.
struct Checkpoint: Sendable {
    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    init() {
        (self.stream, self.continuation) = AsyncStream.makeStream(of: Void.self)
    }

    /// Marks the checkpoint reached. Reaching it again is harmless.
    func reach() {
        self.continuation.yield(())
        self.continuation.finish()
    }

    /// Suspends until the checkpoint is reached, returning at once if it already has been.
    func wait() async {
        for await _ in self.stream { return }
    }
}
