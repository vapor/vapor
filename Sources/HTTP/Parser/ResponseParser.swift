import CHTTP
import Async
import Bits
import Foundation

/// Parses requests from a readable stream.
public final class ResponseParser: CParser, Async.Stream, ClosableStream {
    /// See InputStream.Input
    public typealias Input = ByteBuffer

    /// See OutputStream.Output
    public typealias Output = Response
    
    // Internal variables to conform
    // to the C HTTP parser protocol.
    var parser: http_parser
    var settings: http_parser_settings
    var state:  CHTTPParserState

    /// The maxiumum possible body size
    /// larger sizes will result in an error
    private let maxSize: Int
    
    /// The currently parsing response's size
    private var currentSize = 0

    /// Use a basic stream to easily implement our output stream.
    private var outputStream: BasicStream<Output>
    
    /// Creates a new Request parser.
    public init(maxSize: Int) {
        self.parser = http_parser()
        self.settings = http_parser_settings()
        self.state = .ready
        self.maxSize = maxSize
        self.outputStream = .init()
        reset(HTTP_RESPONSE)
    }

    /// Resets the parser so it can accept new data.
    /// Call this method if parsing fails.
    func reset() {
        http_parser_init(&parser, HTTP_REQUEST)
        initialize(&settings)
    }
    
    /// Handles incoming stream data
    public func onInput(_ input: ByteBuffer) {
        do {
            guard let request = try parse(from: input) else {
                return
            }
            
            outputStream.onInput(request)
        } catch {
            onError(error)
            reset(HTTP_RESPONSE)
        }
    }
    
    /// See ClosableStream.close
    public func close() {
        self.outputStream.close()
    }
    
    /// See ClosableStream.onClose
    public func onClose(_ onClose: ClosableStream) {
        self.outputStream.onClose(onClose)
    }
    
    /// See InputStream.onError
    public func onError(_ error: Error) {
        outputStream.onError(error)
    }

    /// See OutputStream.onOutput
    public func onOutput<I>(_ input: I) where I: Async.InputStream, Output == I.Input {
        outputStream.onOutput(input)
    }

    /// Parses the supplied data into a response or throws an error.
    /// If the data is incomplete, a nil response will be returned.
    /// Contiguous data may be supplied as multiple calls.
    public func parse(from data: Data) throws -> Response? {
        return try data.withUnsafeBytes { (pointer: BytesPointer) in
            let buffer = ByteBuffer(start: pointer, count: data.count)
            return try parse(from: buffer)
        }
    }
    
    /// Parses a Request from the stream.
    public func parse(from buffer: ByteBuffer) throws -> Response? {
        currentSize += buffer.count
        
        guard currentSize < maxSize else {
            throw HTTPError(identifier: "too-large-response", reason: "The response's size was not an acceptable size")
        }
        
        let results: CParseResults
        
        switch state {
        case .ready:
            // create a new results object and set
            // a reference to it on the parser
            let newResults = CParseResults.set(on: &parser, maxSize: maxSize)
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

        /// get response status
        let status = Status(code: Int(parser.status_code))

        // require a version to have been parsed
        guard let version = results.version else {
            throw HTTPError.invalidMessage()
        }
        
        let body = Body(results.body)
        
        let headers = Headers(storage: results.headersData, indexes: results.headersIndexes)
        
        currentSize = 0
        
        // create the request
        return Response(
            version: version,
            status: status,
            headers: headers,
            body: body
        )
    }
}


