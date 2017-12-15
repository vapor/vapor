import Async

/// An inverse client stream accepting responses and outputting requests.
/// Used to implement HTTPClient. Should be kept internal
internal final class HTTPClientStream: Stream, OutputRequest {
    /// See InputStream.Input
    typealias Input = HTTPResponse

    /// See OutputStream.Output
    typealias Output = HTTPRequest

    /// Queue of promised responses
    var responseQueue: [Promise<HTTPResponse>]

    /// Queue of requests to be serialized
    var requestQueue: [HTTPRequest]

    /// Accepts serialized requests
    var downstream: AnyInputStream!

    /// Serialized requests
    var remainingDownstreamRequests: UInt {
        didSet { print("remainingDownstreamRequests: \(remainingDownstreamRequests)") }
    }

    /// Parsed responses
    var upstream: OutputRequest!

    /// Creates a new HTTP client stream
    init() {
        self.responseQueue = []
        self.requestQueue = []
        self.remainingDownstreamRequests = 0
    }

    /// Updates the stream's state. If there are outstanding
    /// downstream requests, they will be fulfilled.
    func update() {
        guard remainingDownstreamRequests > 0 else {
            return
        }
        while let request = requestQueue.popLast() {
            remainingDownstreamRequests -= 1
            downstream.unsafeOnInput(request)
        }
    }

    /// MARK: OutputRequest

    /// See OutputRequest.requestOutput
    func requestOutput(_ count: UInt) {
        let isSuspended = remainingDownstreamRequests == 0
        remainingDownstreamRequests += count
        if isSuspended { update() }
    }

    /// See OutputRequest.cancelOutput
    func cancelOutput() {
        /// FIXME: better cancel support
        remainingDownstreamRequests = 0
    }

    /// MARK: OutputStream

    /// See OutputStream.output(to:)
    func output<S>(to inputStream: S) where S : InputStream, S.Input == HTTPRequest {
        downstream = inputStream
        inputStream.onOutput(self)
    }

    /// MARK: InputStream

    /// See InputStream.onInput
    func onInput(_ input: HTTPResponse) {
        let promise = responseQueue.popLast()!
        promise.complete(input)
        update()
    }

    /// See InputStream.onOutput
    func onOutput(_ outputRequest: OutputRequest) {
        upstream = outputRequest
    }

    /// See InputStream.onError
    func onError(_ error: Error) {
        downstream.onError(error)
    }

    /// See InputStream.onClose
    func onClose() {
        downstream.onClose()
    }
}
