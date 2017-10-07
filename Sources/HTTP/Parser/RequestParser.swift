import Bits
import CHTTP
import Core
import Dispatch
import Foundation

/// Parses requests from a readable stream.
public final class RequestParser: CParser {
    // MARK: Stream
    public typealias Input = ByteBuffer
    public typealias Output = Request
    public var outputStream: OutputHandler?
    public var errorStream: ErrorHandler?

    // Internal variables to conform
    // to the C HTTP parser protocol.
    var parser: http_parser
    var settings: http_parser_settings
    var state:  CHTTPParserState

    /// Queue to be set on messages created by this parser.
    private let worker: Worker

    /// Creates a new Request parser.
    public init(worker: Worker) {
        self.parser = http_parser()
        self.settings = http_parser_settings()
        self.state = .ready
        self.worker = worker
        reset(HTTP_REQUEST)
    }

    /// Handles incoming stream data
    public func inputStream(_ input: ByteBuffer) {
        do {
            guard let request = try parse(from: input) else {
                return
            }
            outputStream?(request)
        } catch {
            self.errorStream?(error)
            reset(HTTP_REQUEST)
        }
    }

    /// Parses request Data. If the data does not contain
    /// an entire HTTP request, nil will be returned and
    /// the parser will remain ready to accept new Data.
    public func parse(from data: Data) throws -> Request? {
        return try data.withUnsafeBytes { (pointer: BytesPointer) in
            let buffer = ByteBuffer(start: pointer, count: data.count)
            return try parse(from: buffer)
        }
    }

    /// Parses a Request from the stream.
    public func parse(from buffer: ByteBuffer) throws -> Request? {
        let results: CParseResults

        switch state {
        case .ready:
            // create a new results object and set
            // a reference to it on the parser
            let newResults = CParseResults.set(on: &parser)
            results = newResults
            state = .parsing
        case .parsing:
            // get the current parse results object
            guard let existingResults = CParseResults.get(from: &parser) else {
                return nil
            }
            results = existingResults
        }

        /// parse the message using the C HTTP parser.
        try executeParser(max: buffer.count, from: buffer)

        guard results.isComplete else {
            return nil
        }

        // the results have completed, so we are ready
        // for a new request to come in
        state = .ready
        CParseResults.remove(from: &parser)


        /// switch on the C method type from the parser
        let method: Method
        switch http_method(parser.method) {
        case HTTP_DELETE:
            method = .delete
        case HTTP_GET:
            method = .get
        case HTTP_POST:
            method = .post
        case HTTP_PUT:
            method = .put
        case HTTP_OPTIONS:
            method = .options
        case HTTP_PATCH:
            method = .patch
        default:
            /// custom method detected,
            /// convert the method into a string
            /// and use Engine's other type
            guard
                let pointer = http_method_str(http_method(parser.method)),
                let string = String(validatingUTF8: pointer)
            else {
                throw Error.invalidMessage()
            }
            method = Method(string)
        }

        // parse the uri from the url bytes.
        var uri = URIParser.shared.parse(bytes: results.url!)
        let headers = Headers(storage: results.headers)

        // if there is no scheme, use http by default
        if uri.scheme?.isEmpty == true {
            uri.scheme = "http"
        }

        // require a version to have been parsed
        guard let version = results.version else {
            throw Error.invalidMessage()
        }

        let body: Body
        if let data = results.body {
            body = Body(data)
        } else {
            body = Body()
        }

        // create the request
        let request = Request(
            method: method,
            uri: uri,
            version: version,
            headers: headers,
            body: body
        )

        request.worker = self.worker
        return request
    }
}

