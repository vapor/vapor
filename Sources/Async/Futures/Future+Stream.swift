import Dispatch

extension Future {
    /// Streams the result of this future to the InputStream
    ///
    /// http://localhost:8000/async/streams-basics/#chaining-streams_1
    public func stream<S: InputStream>(to stream: S) where S.Input == Expectation {
        then(callback: stream.inputStream).catch { error in
            stream.errorStream?(error)
        }
    }
}
