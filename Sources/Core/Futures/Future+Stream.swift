import Dispatch

extension Future {
    /// Streams the result of this future to the InputStream
    public func stream<S: InputStream>(to stream: S) where S.Input == Expectation {
        then(callback: stream.inputStream).catch { error in
            stream.errorStream?(error)
        }
    }
}
